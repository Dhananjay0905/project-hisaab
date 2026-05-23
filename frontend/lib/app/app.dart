/// Root app widget — wires MaterialApp.router with ProviderScope.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../core/network/api_client.dart';
import '../core/providers/colorblind_provider.dart';
import '../core/providers/share_intent_provider.dart';
import '../core/providers/theme_mode_provider.dart';
import '../core/services/upi_transaction_data.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/semantic_colors.dart';
import '../core/widgets/update_guard.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/legal/presentation/providers/legal_provider.dart';

/// ScaffoldMessenger key used to show snackbars from share-intent callbacks
/// without needing a BuildContext — works even when called before the scaffold
/// is in the widget tree.
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class HisaabApp extends ConsumerStatefulWidget {
  const HisaabApp({super.key});

  @override
  ConsumerState<HisaabApp> createState() => _HisaabAppState();
}

class _HisaabAppState extends ConsumerState<HisaabApp> {
  /// Tracks the last intentId we navigated for.
  int _lastHandledIntentId = 0;

  // ─── Deep link state ────────────────────────────────────────────────────────
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSub;

  /// Token from a `hisaab://reset-password?token=...` deep link that arrived
  /// before auth finished initialising. Processed once auth state settles.
  String? _pendingResetToken;

  @override
  void initState() {
    super.initState();
    ApiClient.instance.init(
      onSessionExpired: () =>
          ref.read(authNotifierProvider.notifier).forceLogout(),
    );
    ref.read(legalProvider);
    ref.read(shareIntentProvider.notifier).init();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  // ─── Snackbar helper ────────────────────────────────────────────────────────

  /// Shows a snackbar via the root ScaffoldMessenger key — works even from
  /// share-intent callbacks that run before a local BuildContext is available.
  /// Duration is 5 seconds so the user has time to read the message.
  void _showShareSnackBar(String message, {bool isError = false}) {
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? Theme.of(messenger.context).colorScheme.error
            : null,
        showCloseIcon: true,
      ),
    );
  }

  // ─── Deep link handling ──────────────────────────────────────────────────────

  /// Subscribes to the app_links stream.
  /// • Cold start: reads the initial URI that launched the app.
  /// • Warm start: listens for URIs while the app is already running.
  Future<void> _initDeepLinks() async {
    // Cold start — grab the URI that caused the app to open, if any.
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null && mounted) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('[DeepLink] Error reading initial link: $e');
    }

    // Warm start — stream of subsequent deep links while app is running.
    _deepLinkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (mounted) _handleDeepLink(uri);
      },
      onError: (e) => debugPrint('[DeepLink] Stream error: $e'),
    );
  }

  /// Dispatches a deep link URI to the appropriate handler.
  void _handleDeepLink(Uri uri) {
    debugPrint('[DeepLink] Received: $uri');
    // hisaab://reset-password?token=TOKEN
    if (uri.scheme == 'hisaab' && uri.host == 'reset-password') {
      final token = uri.queryParameters['token'] ?? '';
      if (token.isEmpty) return;
      _pendingResetToken = token;
      _tryNavigateToReset();
    }
  }

  /// Navigates to /reset-password if there is a pending token and auth has
  /// finished initialising (i.e. the router redirect logic is stable).
  void _tryNavigateToReset() {
    if (_pendingResetToken == null) return;

    final authAsync = ref.read(authNotifierProvider);
    final isInitializing =
        authAsync.isLoading &&
        ref.read(authNotifierProvider.notifier).isInitializing;

    // Not ready yet — wait for the auth listener in build() to retry.
    if (isInitializing) return;

    final token = _pendingResetToken!;
    _pendingResetToken = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('[DeepLink] Navigating to /reset-password with token');
      ref.read(routerProvider).go('/reset-password?token=$token');
    });
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _tryNavigateToAddTransaction() {
    final intentState = ref.read(shareIntentProvider);

    debugPrint('[App] _tryNavigate: data=${intentState.data != null}, '
        'intentId=${intentState.intentId}, '
        'lastHandled=$_lastHandledIntentId, '
        'processing=${intentState.isProcessing}');

    if (intentState.data == null) {
      debugPrint('[App] _tryNavigate: SKIP — no data');
      return;
    }
    if (intentState.intentId <= _lastHandledIntentId) {
      debugPrint('[App] _tryNavigate: SKIP — already handled');
      return;
    }

    final auth = ref.read(authNotifierProvider).valueOrNull;
    if (auth is! AuthAuthenticated) {
      debugPrint('[App] _tryNavigate: SKIP — not authenticated (auth=$auth)');
      return;
    }

    _lastHandledIntentId = intentState.intentId;
    final upiData = intentState.data!;
    final isPartial = !upiData.hasMinimumData; // amount is missing
    debugPrint('[App] ✅ Navigating to /add-transaction for intent #${intentState.intentId} '
        '(partial=$isPartial)');

    final router = ref.read(routerProvider);
    // Wrap the UpiTransactionData in a _UpiIntentExtra so the route knows
    // whether to show the full or partial banner.
    router.push('/add-transaction', extra: UpiIntentExtra(upiData, isPartial: isPartial));
    ref.read(shareIntentProvider.notifier).consume();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final isColorblind = ref.watch(colorblindProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Listen for new share intent data
    ref.listen<ShareIntentState>(shareIntentProvider, (prev, next) {
      debugPrint('[App] shareIntent listener: '
          'prev=(data=${prev?.data != null}, id=${prev?.intentId}) → '
          'next=(data=${next.data != null}, isNotUpi=${next.isNotUpiReceipt}, '
          'isOcrError=${next.isOcrError}, id=${next.intentId})');

      // Non-UPI image — show a friendly snackbar, do NOT open the modal.
      if (next.isNotUpiReceipt && next.intentId > _lastHandledIntentId) {
        _lastHandledIntentId = next.intentId;
        ref.read(shareIntentProvider.notifier).consume();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showShareSnackBar(
              "That image doesn't look like a UPI receipt. "
              'Share a payment screenshot to auto-fill.',
            );
          }
        });
        return;
      }

      // OCR threw an exception — show an error snackbar.
      if (next.isOcrError && next.intentId > _lastHandledIntentId) {
        _lastHandledIntentId = next.intentId;
        ref.read(shareIntentProvider.notifier).consume();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showShareSnackBar(
              'Something went wrong while reading the screenshot. Please try again.',
              isError: true,
            );
          }
        });
        return;
      }

      // Valid data (full or partial) — navigate to the modal.
      if (next.data != null && next.intentId > _lastHandledIntentId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryNavigateToAddTransaction();
        });
      }
    });

    // Listen for auth changes — handles both pending share intents and pending
    // deep links (e.g. reset-password) that arrived before auth settled.
    ref.listen<AsyncValue<AuthStatus>>(authNotifierProvider, (prev, next) {
      if (next.valueOrNull is AuthAuthenticated) {
        debugPrint('[App] Auth became authenticated — checking for pending intent');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tryNavigateToAddTransaction();
        });
      }
      // When auth finishes initialising, retry any pending deep link navigation.
      if (!next.isLoading) {
        _tryNavigateToReset();
      }
    });

    final lightSemanticColors =
        isColorblind ? SemanticColors.colorblind : SemanticColors.normal;
    final darkSemanticColors =
        isColorblind ? SemanticColors.colorblindDark : SemanticColors.normalDark;

    return UpdateGuard(
      child: MaterialApp.router(
        title: 'Hisaab',
        theme: AppTheme.lightWith(lightSemanticColors),
        darkTheme: AppTheme.darkWith(darkSemanticColors),
        themeMode: themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        // ScaffoldMessenger key lets _showShareSnackBar display snackbars from
        // share-intent callbacks without needing a widget-tree BuildContext.
        scaffoldMessengerKey: _scaffoldMessengerKey,
      ),
    );
  }
}

// ─── UPI intent extra ──────────────────────────────────────────────────────────

/// Wraps [UpiTransactionData] with a [isPartial] flag so the router can pass
/// both pieces of information to [AddTransactionPage] in one go_router extra.
class UpiIntentExtra {
  const UpiIntentExtra(this.data, {required this.isPartial});

  final UpiTransactionData data;

  /// True when OCR did not find an amount — the modal should show a
  /// "couldn't read all details" warning rather than the success banner.
  final bool isPartial;
}
