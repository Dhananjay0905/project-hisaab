/// ShareIntentProvider — listens for images shared to Hisaab from other apps
/// (e.g. GPay, PhonePe) and OCRs them to extract UPI transaction details.
///
/// Architecture notes:
///   The receive_sharing_intent plugin fires BOTH getInitialMedia() AND
///   getMediaStream() for the very first intent (the one that launched the
///   Activity). This means the same image would be OCR'd twice if we naively
///   listened to both. To avoid that, we track the last processed file path
///   and skip duplicates.
///
///   For subsequent shares (onNewIntent while app is already running), only
///   the stream fires, so there's no duplication concern.
///
///   Each successfully-parsed result gets a unique [intentId] (a monotonically
///   increasing counter) so the listener in app.dart can distinguish a truly
///   new result from a stale one, even if the underlying UpiTransactionData
///   is identical.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../services/upi_ocr_service.dart';
import '../services/upi_transaction_data.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class ShareIntentState {
  const ShareIntentState({
    this.data,
    this.isProcessing = false,
    this.error,
    this.intentId = 0,
  });

  final UpiTransactionData? data;
  final bool isProcessing;
  final String? error;

  /// Monotonically increasing ID. Every new intent bumps this, letting
  /// listeners detect "new data" even after a consume() → new-data cycle.
  final int intentId;

  bool get hasData => data != null && data!.hasAnyData;

  ShareIntentState copyWith({
    UpiTransactionData? data,
    bool? isProcessing,
    String? error,
    int? intentId,
  }) {
    return ShareIntentState(
      data: data ?? this.data,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
      intentId: intentId ?? this.intentId,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ShareIntentNotifier extends StateNotifier<ShareIntentState> {
  ShareIntentNotifier() : super(const ShareIntentState());

  StreamSubscription<List<SharedMediaFile>>? _streamSub;

  /// The file path of the last intent we processed (or are currently
  /// processing). Used to deduplicate the initial-media / stream double-fire.
  String? _lastProcessedPath;

  /// Counter for unique intent IDs.
  int _nextIntentId = 1;

  /// Whether the initial media has already been handled. If so, the stream
  /// listener should skip any event that arrives with the same path.
  bool _initialHandled = false;

  /// Call this once during app startup.
  void init() {
    // 1) Handle initial share (app launched FROM a share action).
    //    This ALSO fires via the stream, so we track the path.
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) {
        _initialHandled = true;
        _handleSharedFiles(files);
      }
    });

    // 2) Handle shares while the app is already running.
    _streamSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isEmpty) return;

        // Deduplicate: if the initial media was already handled and this
        // stream event has the exact same path, skip it.
        final streamPath = _extractImagePath(files);
        if (_initialHandled && streamPath != null && streamPath == _lastProcessedPath) {
          debugPrint('[ShareIntent] Skipping duplicate stream event for: $streamPath');
          return;
        }

        _handleSharedFiles(files);
      },
      onError: (err) {
        state = state.copyWith(error: err.toString());
      },
    );
  }

  /// Extract the image path from a list of shared files (returns null if none).
  String? _extractImagePath(List<SharedMediaFile> files) {
    for (final f in files) {
      final path = f.path.toLowerCase();
      if (f.type == SharedMediaType.image ||
          path.endsWith('.jpg') ||
          path.endsWith('.jpeg') ||
          path.endsWith('.png') ||
          path.endsWith('.webp')) {
        return f.path;
      }
    }
    return null;
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    // Find the first image file
    final imagePath = _extractImagePath(files);
    if (imagePath == null) return;

    // Deduplicate: if we're already processing (or just processed) this path,
    // don't start again. This catches the initial+stream double-fire.
    if (imagePath == _lastProcessedPath && state.isProcessing) {
      debugPrint('[ShareIntent] Already processing $imagePath, skipping');
      return;
    }

    _lastProcessedPath = imagePath;
    final thisIntentId = _nextIntentId++;

    state = ShareIntentState(isProcessing: true, intentId: thisIntentId);

    try {
      final upiData = await UpiOcrService.instance.parseScreenshot(imagePath);
      debugPrint('[ShareIntent] OCR result: $upiData');

      // Only update state if this is still the latest intent (user might have
      // shared something else while we were OCR-ing).
      if (thisIntentId == _nextIntentId - 1) {
        state = ShareIntentState(
          data: upiData,
          isProcessing: false,
          intentId: thisIntentId,
        );
      }
    } catch (e) {
      debugPrint('[ShareIntent] OCR error: $e');
      if (thisIntentId == _nextIntentId - 1) {
        state = ShareIntentState(
          isProcessing: false,
          error: 'Could not read screenshot: $e',
          intentId: thisIntentId,
        );
      }
    }
  }

  /// Call after the app has consumed the parsed data (e.g. navigation done).
  ///
  /// Clears the data but preserves the intentId so listeners don't re-trigger.
  /// Does NOT call ReceiveSharingIntent.instance.reset() — that kills the
  /// native stream and breaks subsequent shares.
  void consume() {
    state = ShareIntentState(intentId: state.intentId);
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final shareIntentProvider =
    StateNotifierProvider<ShareIntentNotifier, ShareIntentState>(
  (ref) => ShareIntentNotifier(),
);
