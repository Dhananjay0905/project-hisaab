/// ShareIntentProvider — listens for images shared to Hisaab from other apps
/// (e.g. GPay, PhonePe) and OCRs them to extract UPI transaction details.
///
/// Usage:
///   - Initialize in app startup with [ShareIntentNotifier.init]
///   - Watch [shareIntentProvider] to be notified of new shared data
///   - Call [ShareIntentNotifier.consume] after handling to clear state
library;

import 'dart:async';

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
  });

  final UpiTransactionData? data;
  final bool isProcessing;
  final String? error;

  bool get hasData => data != null && data!.hasAnyData;

  ShareIntentState copyWith({
    UpiTransactionData? data,
    bool? isProcessing,
    String? error,
  }) {
    return ShareIntentState(
      data: data ?? this.data,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error ?? this.error,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ShareIntentNotifier extends StateNotifier<ShareIntentState> {
  ShareIntentNotifier() : super(const ShareIntentState());

  StreamSubscription<List<SharedMediaFile>>? _streamSub;

  /// Call this once during app startup.
  /// Handles both:
  ///   1. App launched directly FROM a share action (initial intent)
  ///   2. App already running when a share action arrives (stream)
  void init() {
    // Handle initial share when app is launched fresh from share intent
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty) _handleSharedFiles(files);
    });

    // Handle share while app is already in foreground/background.
    // Store the subscription so we can cancel it on dispose — prevents
    // stale subscriptions if the provider is ever reset.
    _streamSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (files) {
        if (files.isNotEmpty) _handleSharedFiles(files);
      },
      onError: (err) {
        state = state.copyWith(error: err.toString());
      },
    );
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    // Only interested in image files
    final imageFile = files.firstWhere(
      (f) =>
          f.type == SharedMediaType.image ||
          (f.path.toLowerCase().endsWith('.jpg') ||
              f.path.toLowerCase().endsWith('.jpeg') ||
              f.path.toLowerCase().endsWith('.png') ||
              f.path.toLowerCase().endsWith('.webp')),
      orElse: () => files.first,
    );

    // Quick mime type check
    final path = imageFile.path;
    final isImage = path.toLowerCase().endsWith('.jpg') ||
        path.toLowerCase().endsWith('.jpeg') ||
        path.toLowerCase().endsWith('.png') ||
        path.toLowerCase().endsWith('.webp') ||
        imageFile.type == SharedMediaType.image;

    if (!isImage) return;

    state = state.copyWith(isProcessing: true);

    try {
      final upiData = await UpiOcrService.instance.parseScreenshot(path);
      state = ShareIntentState(data: upiData, isProcessing: false);
    } catch (e) {
      state = ShareIntentState(
        isProcessing: false,
        error: 'Could not read screenshot: $e',
      );
    }
  }

  /// Call after the app has consumed the parsed data (e.g. navigation done).
  ///
  /// IMPORTANT: We intentionally do NOT call ReceiveSharingIntent.instance.reset()
  /// here. That method resets the native-side stream, which prevents any future
  /// share intents from being delivered while the app is still running. Removing
  /// it means the user can share multiple transactions in a row without restarting.
  void consume() {
    state = const ShareIntentState();
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
