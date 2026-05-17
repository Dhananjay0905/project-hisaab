/// Root app widget — wires MaterialApp.router with ProviderScope.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../core/network/api_client.dart';
import '../core/providers/colorblind_provider.dart';
import '../core/providers/theme_mode_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/semantic_colors.dart';
import '../features/auth/presentation/providers/auth_provider.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isColorblind = ref.watch(colorblindProvider);
    final themeMode = ref.watch(themeModeProvider);

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
