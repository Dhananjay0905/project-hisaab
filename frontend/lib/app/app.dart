/// Root app widget — wires MaterialApp.router with ProviderScope.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../core/network/api_client.dart';
import '../core/providers/colorblind_provider.dart';
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
    final semanticColors =
        isColorblind ? SemanticColors.colorblind : SemanticColors.normal;

    return MaterialApp.router(
      title: 'Hisaab',
      theme: AppTheme.lightWith(semanticColors),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
