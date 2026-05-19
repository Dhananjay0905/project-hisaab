/// Root app widget — wires MaterialApp.router with ProviderScope.
library;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../core/network/api_client.dart';
import '../core/providers/colorblind_provider.dart';
import '../core/providers/share_intent_provider.dart';
import '../core/providers/theme_mode_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/semantic_colors.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/legal/presentation/providers/legal_provider.dart';

class HisaabApp extends ConsumerStatefulWidget {
  const HisaabApp({super.key});

  @override
  ConsumerState<HisaabApp> createState() => _HisaabAppState();
}

class _HisaabAppState extends ConsumerState<HisaabApp> {
  /// Tracks the last intentId we navigated for, so we never navigate
  /// twice for the same shared image (even across listen + postFrame checks).
  int _lastHandledIntentId = 0;

  @override
  void initState() {
    super.initState();
    // Re-init ApiClient with the session-expired callback now that Riverpod is ready.
    ApiClient.instance.init(
      onSessionExpired: () =>
          ref.read(authNotifierProvider.notifier).forceLogout(),
    );
    // Prefetch legal terms (Privacy Policy & ToS) to skip any loading states in the app
    ref.read(legalProvider);
    // Start listening for shared images (UPI screenshots from GPay, PhonePe, etc.)
    ref.read(shareIntentProvider.notifier).init();

    // Race-condition fix: if the OCR finishes before the first build() runs
    // (and ref.listen is registered), we'd miss the state transition.
    // Check once after the first frame — if data is already there, navigate.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _tryNavigateToAddTransaction();
    });
  }

  /// Navigates to add-transaction if there's pending UPI data that we
  /// haven't handled yet. Uses [_lastHandledIntentId] to prevent
  /// double-navigation from both ref.listen and the post-frame callback.
  void _tryNavigateToAddTransaction() {
    final intentState = ref.read(shareIntentProvider);

    // Nothing to do if no data, still processing, or already handled this intent
    if (intentState.data == null) return;
    if (intentState.intentId <= _lastHandledIntentId) return;

    // Only navigate if the user is authenticated
    final auth = ref.read(authNotifierProvider).valueOrNull;
    if (auth is! AuthAuthenticated) return;

    _lastHandledIntentId = intentState.intentId;

    final router = ref.read(routerProvider);

    // If the add-transaction modal is already open (user shared a 2nd image
    // quickly), pop it first so we don't stack multiple modals.
    final currentUri = router.routeInformationProvider.value.uri.toString();
    if (currentUri.contains('add-transaction')) {
      router.pop();
      // Give the pop animation a moment to complete, then push the new one.
      Future.delayed(const Duration(milliseconds: 300), () {
        router.push('/add-transaction', extra: intentState.data);
        ref.read(shareIntentProvider.notifier).consume();
      });
    } else {
      router.push('/add-transaction', extra: intentState.data);
      ref.read(shareIntentProvider.notifier).consume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isColorblind = ref.watch(colorblindProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Navigate to add-transaction whenever a UPI share intent is processed.
    ref.listen<ShareIntentState>(shareIntentProvider, (prev, next) {
      // Only react when new data arrives with a new intentId
      if (next.data != null &&
          next.intentId > _lastHandledIntentId) {
        _tryNavigateToAddTransaction();
      }
    });

    // Pick the correct semantic colors based on both colorblind and theme mode.
    final lightSemanticColors =
        isColorblind ? SemanticColors.colorblind : SemanticColors.normal;
    final darkSemanticColors =
        isColorblind ? SemanticColors.colorblindDark : SemanticColors.normalDark;

    return MaterialApp.router(
      title: 'Hisaab',
      theme: AppTheme.lightWith(lightSemanticColors),
      darkTheme: AppTheme.darkWith(darkSemanticColors),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
