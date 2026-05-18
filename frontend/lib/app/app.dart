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
  /// Tracks whether we've already navigated for the current share intent,
  /// so we don't push the route twice (once from listen, once from build).
  bool _hasNavigatedForShareIntent = false;

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
  }

  /// Attempts to navigate to /add-transaction with the current share intent data.
  /// Safe to call multiple times — guarded by [_hasNavigatedForShareIntent].
  void _maybeNavigateForShareIntent(GoRouter router) {
    if (_hasNavigatedForShareIntent) return;

    final shareState = ref.read(shareIntentProvider);
    // Still processing OCR — wait for the next state update
    if (shareState.isProcessing) return;
    // No data yet (no share intent active)
    if (shareState.data == null) return;

    final auth = ref.read(authNotifierProvider).valueOrNull;
    if (auth is! AuthAuthenticated) return;

    _hasNavigatedForShareIntent = true;
    // Capture data before consuming so AddTransactionPage receives it
    final data = shareState.data;
    router.push('/add-transaction', extra: data);
    // Delay consume until after the route is pushed so the page can read the data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shareIntentProvider.notifier).consume();
      _hasNavigatedForShareIntent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isColorblind = ref.watch(colorblindProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Listen for share intent state changes (handles: app running in bg, stream delivery)
    ref.listen<ShareIntentState>(shareIntentProvider, (prev, next) {
      if (!next.isProcessing && next.data != null) {
        _maybeNavigateForShareIntent(router);
      }
    });

    // Listen for auth state changes (handles: race condition where OCR finishes
    // before auth completes — e.g. app cold-started from share intent)
    ref.listen<AsyncValue<AuthStatus>>(authNotifierProvider, (prev, next) {
      if (next.valueOrNull is AuthAuthenticated) {
        _maybeNavigateForShareIntent(router);
      }
    });

    // Pick the correct semantic colors based on both colorblind and theme mode.
    // For ThemeMode.system we let MaterialApp decide which theme to use,
    // so we provide both light and dark semantic colors.
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
