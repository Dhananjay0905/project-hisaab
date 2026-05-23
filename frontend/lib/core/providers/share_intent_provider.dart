/// ShareIntentProvider — listens for images shared to Hisaab from other apps
/// (e.g. GPay, PhonePe) and OCRs them to extract UPI transaction details.
///
/// Deduplication strategy:
///   The receive_sharing_intent plugin fires BOTH getInitialMedia() AND
///   getMediaStream() for the very first intent. To avoid double-processing,
///   we use a short time window (1 second): if we receive the same file path
///   within 1s of the last processing start, we skip it. This cleanly handles
///   the initial double-fire (milliseconds apart) without blocking a legitimate
///   re-share of the same image minutes later.
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
    this.isNotUpiReceipt = false,
    this.isOcrError = false,
  });

  final UpiTransactionData? data;
  final bool isProcessing;
  final String? error;

  /// Monotonically increasing ID. Every new intent bumps this, letting
  /// listeners detect "new data" even after a consume() → new-data cycle.
  final int intentId;

  /// True when the shared image was determined not to be a UPI receipt
  /// (e.g. a random photo). App should show a snackbar rather than the modal.
  final bool isNotUpiReceipt;

  /// True when OCR threw an unexpected exception. App should show an error
  /// snackbar rather than the modal.
  final bool isOcrError;

  bool get hasData => data != null && data!.hasAnyData;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ShareIntentNotifier extends StateNotifier<ShareIntentState> {
  ShareIntentNotifier() : super(const ShareIntentState());

  StreamSubscription<List<SharedMediaFile>>? _streamSub;

  /// Timestamp of the last time we started processing a file.
  DateTime _lastProcessedAt = DateTime(2000);

  /// Path of the file we last started processing.
  String? _lastProcessedPath;

  /// Counter for unique intent IDs.
  int _nextIntentId = 1;

  /// Call this once during app startup.
  void init() {
    // 1) Handle initial share (app launched FROM a share action).
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _handleSharedFiles(files);
    });

    // 2) Handle shares while the app is already running (onNewIntent path).
    _streamSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) _handleSharedFiles(files);
      },
      onError: (err) {
        debugPrint('[ShareIntent] Stream error: $err');
      },
    );
  }

  /// Extract the first image path from a list of shared files.
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
    final imagePath = _extractImagePath(files);
    if (imagePath == null) return;

    // ── Dedup: skip if same path within 1 second (initial double-fire) ──
    final now = DateTime.now();
    if (imagePath == _lastProcessedPath &&
        now.difference(_lastProcessedAt).inMilliseconds < 1000) {
      debugPrint('[ShareIntent] Dedup: skipping duplicate within 1s for $imagePath');
      return;
    }

    _lastProcessedPath = imagePath;
    _lastProcessedAt = now;
    final thisIntentId = _nextIntentId++;

    debugPrint('[ShareIntent] Processing intent #$thisIntentId: $imagePath');
    state = ShareIntentState(isProcessing: true, intentId: thisIntentId);

    try {
      final upiData = await UpiOcrService.instance.parseScreenshot(imagePath);
      debugPrint('[ShareIntent] OCR result #$thisIntentId: $upiData');

      // Only update if this is still the latest intent.
      if (thisIntentId == _nextIntentId - 1) {
        if (upiData.isNotUpiReceipt) {
          // Shared image is not a UPI receipt — signal the app to show a snackbar.
          state = ShareIntentState(
            isNotUpiReceipt: true,
            isProcessing: false,
            intentId: thisIntentId,
          );
        } else {
          state = ShareIntentState(
            data: upiData,
            isProcessing: false,
            intentId: thisIntentId,
          );
        }
      }
    } catch (e) {
      debugPrint('[ShareIntent] OCR error #$thisIntentId: $e');
      if (thisIntentId == _nextIntentId - 1) {
        state = ShareIntentState(
          isProcessing: false,
          isOcrError: true,
          error: e.toString(),
          intentId: thisIntentId,
        );
      }
    }
  }

  /// Call after the app has consumed the parsed data (e.g. navigation done).
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
