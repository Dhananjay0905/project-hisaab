/// Root app widget — wires MaterialApp.router with ProviderScope.
library;

import 'package:flutter/material.dart';
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
  /// twice for the same shared image.
  int _lastHandledIntentId = 0;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.init(
      onSessionExpired: () =>
          ref.read(authNotifierProvider.notifier).forceLogout(),
    );
    ref.read(legalProvider);
    // Start listening for shared images (UPI screenshots from GPay, PhonePe, etc.)
    ref.read(shareIntentProvider.notifier).init();
  }

  /// Navigates to /add-transaction if there's pending UPI data that we
  /// haven't handled yet. Safe to call repeatedly — the intentId check
  /// ensures we only navigate once per intent.
  void _tryNavigateToAddTransaction() {
    final intentState = ref.read(shareIntentProvider);

    // Nothing to do if no data or already handled this intent
    if (intentState.data == null) return;
    if (intentState.intentId <= _lastHandledIntentId) return;

    // Only navigate if the user is authenticated
    final auth = ref.read(authNotifierProvider).valueOrNull;
    if (auth is! AuthAuthenticated) return;

    _lastHandledIntentId = intentState.intentId;
    debugPrint('[App] Navigating to add-transaction for intent #${intentState.intentId}');

    final router = ref.read(routerProvider);
    router.push('/add-transaction', extra: intentState.data);
    ref.read(shareIntentProvider.notifier).consume();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isColorblind = ref.watch(colorblindProvider);
    final themeMode = ref.watch(themeModeProvider);

    // ── Listener 1: New share intent data arrives ──
    // Fires when OCR completes and data is available.
    ref.listen<ShareIntentState>(shareIntentProvider, (prev, next) {
      if (next.data != null && next.intentId > _lastHandledIntentId) {
        // Use a post-frame callback so the router is definitely ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryNavigateToAddTransaction();
        });
      }
    });

    // ── Listener 2: Auth state changes ──
    // This catches the case where OCR finishes BEFORE the user is
    // authenticated (e.g. app launched from a share intent — OCR completes
    // during splash/login). When auth finally resolves, we check for
    // pending intent data and navigate.
    ref.listen<AsyncValue<AuthStatus>>(authNotifierProvider, (prev, next) {
      if (next.valueOrNull is AuthAuthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryNavigateToAddTransaction();
        });
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
