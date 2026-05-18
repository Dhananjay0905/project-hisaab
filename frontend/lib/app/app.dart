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
      _checkAndNavigateIfPending();
    });
  }

  void _checkAndNavigateIfPending() {
    final intentState = ref.read(shareIntentProvider);
    if (intentState.data != null) {
      final auth = ref.read(authNotifierProvider).valueOrNull;
      if (auth is AuthAuthenticated) {
        final router = ref.read(routerProvider);
        router.push('/add-transaction', extra: intentState.data);
        ref.read(shareIntentProvider.notifier).consume();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isColorblind = ref.watch(colorblindProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Navigate to add-transaction whenever a UPI share intent is processed.
    // We listen here (not in initState) so the router is available.
    ref.listen<ShareIntentState>(shareIntentProvider, (prev, next) {
      if (next.data != null && prev?.data == null) {
        // Only navigate if the user is already authenticated
        final auth = ref.read(authNotifierProvider).valueOrNull;
        if (auth is AuthAuthenticated) {
          router.push('/add-transaction', extra: next.data);
          // Mark as consumed so we don't navigate again on hot-reload / re-listen
          ref.read(shareIntentProvider.notifier).consume();
        }
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
