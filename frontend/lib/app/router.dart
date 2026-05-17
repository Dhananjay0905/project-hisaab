/// go_router configuration with StatefulShellRoute for 4 persistent tabs
/// and full-screen routes for auth + add-transaction.
///
/// Auth redirect rules:
///   • No session → /login (unless already on an auth route)
///   • Authenticated + on auth route → /home
///   • Email unverified → /verify-email
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/auth/presentation/pages/splash_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';
import '../features/auth/presentation/pages/account_deletion_scheduled_page.dart';
import '../features/auth/presentation/providers/auth_provider.dart';
import '../features/legal/presentation/pages/policy_acceptance_page.dart';
import '../features/legal/presentation/pages/privacy_policy_page.dart';
import '../features/legal/presentation/pages/terms_of_service_page.dart';
import '../features/categories/presentation/pages/categories_page.dart';
import '../features/dashboard/presentation/pages/home_page.dart';
import '../features/more/presentation/pages/more_page.dart';
import '../features/recurring/presentation/pages/recurring_page.dart';
import '../features/savings/presentation/pages/savings_page.dart';
import '../features/transactions/presentation/pages/add_transaction_page.dart';
import '../features/dues/presentation/pages/dues_page.dart';
import '../features/transactions/presentation/pages/transactions_page.dart';
import '../features/wishlist/presentation/pages/wishlist_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/analytics/presentation/pages/analytics_page.dart';
import '../shared/widgets/app_shell.dart';
// Data providers — invalidated on sign-out
import '../features/analytics/presentation/providers/analytics_provider.dart';
import '../features/categories/presentation/providers/categories_provider.dart';
import '../features/dashboard/presentation/providers/summary_provider.dart';
import '../features/dues/presentation/providers/dues_provider.dart';
import '../features/recurring/presentation/providers/recurring_provider.dart';
import '../features/savings/presentation/providers/savings_provider.dart';
import '../features/splits/presentation/providers/splits_provider.dart';
import '../features/transactions/presentation/providers/transactions_provider.dart';
import '../features/wishlist/presentation/providers/wishlist_provider.dart';

// ─── Auth redirect notifier ───────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthStatus>>(
      authNotifierProvider,
      (prev, next) {
        // Invalidate all user-scoped data providers when a NEW user logs in.
        // This ensures stale data from the previous account is never shown.
        // We do this on LOGIN (not logout) so the token is already valid
        // by the time providers rebuild — avoiding 401s from re-fetching
        // with no credentials.
        final wasLoggedOut = prev?.valueOrNull is AuthUnauthenticated ||
            prev?.valueOrNull is AuthSessionExpired ||
            prev?.valueOrNull == null;
        final isNowAuthenticated = next.valueOrNull is AuthAuthenticated;
        if (wasLoggedOut && isNowAuthenticated) {
          _ref.invalidate(transactionsProvider);
          _ref.invalidate(categoriesProvider);
          _ref.invalidate(dashboardSummaryProvider);
          _ref.invalidate(duesProvider);
          _ref.invalidate(duesSummaryProvider);
          _ref.invalidate(recurringProvider);
          _ref.invalidate(dueRecurringProvider);
          _ref.invalidate(savingsProvider);
          _ref.invalidate(splitsProvider);
          _ref.invalidate(wishlistProvider);
          _ref.invalidate(monthlyTrendProvider);
          _ref.invalidate(categorySpendProvider);
        }
        notifyListeners();
      },
    );
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authNotifierProvider);
    final loc = state.matchedLocation;

    // Only redirect to splash during the INITIAL session check.
    // During login/register the state is also loading, but the user
    // must stay on their current page so the inline error/spinner works.
    final isInitializing =
        authAsync.isLoading && _ref.read(authNotifierProvider.notifier).isInitializing;
    if (isInitializing) {
      return loc == '/splash' ? null : '/splash';
    }

    // If loading but NOT initializing (i.e. a login/register in-flight),
    // keep the user exactly where they are.
    if (authAsync.isLoading) return null;

    final auth = authAsync.valueOrNull;

    final isAuthRoute = loc.startsWith('/login') ||
        loc.startsWith('/register') ||
        loc.startsWith('/verify-email') ||
        loc.startsWith('/forgot-password') ||
        loc.startsWith('/reset-password');

    // Legal viewer routes are always accessible (linked from acceptance page)
    final isLegalRoute = loc.startsWith('/privacy-policy') ||
        loc.startsWith('/terms-of-service');

    if (auth == null || auth is AuthUnauthenticated) {
      return isAuthRoute ? null : '/login';
    }

    if (auth is AuthSessionExpired) {
      // Redirect to login with a flag so the login page can show a snackbar
      return isAuthRoute ? null : '/login?sessionExpired=true';
    }

    if (auth is AuthEmailUnverified) {
      return loc.startsWith('/verify-email') ? null : '/verify-email';
    }

    if (auth is AuthAccountDeletionScheduled) {
      return loc.startsWith('/account-deletion-scheduled') ? null : '/account-deletion-scheduled';
    }

    // Policy not yet accepted — gate the user until they accept
    if (auth is AuthPolicyPending) {
      if (loc.startsWith('/accept-policy') || isLegalRoute) return null;
      return '/accept-policy';
    }

    if (auth is AuthAuthenticated) {
      // Leave splash, auth routes, and the policy gate, send to home
      if (loc == '/splash' || isAuthRoute || loc.startsWith('/accept-policy')) {
        return '/home';
      }
      return null;
    }

    return null;
  }
}

// ─── Router provider ──────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  return GoRouter(
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    initialLocation: '/splash',
    routes: [
      // ── Splash (auth check in-progress) ──────────────────────────────────
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => NoTransitionPage(
          key: state.pageKey,
          child: const SplashPage(),
        ),
      ),
      // ── Auth routes (full-screen, no bottom nav) ──────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _authSlideTransition(
          state,
          const LoginPage(),
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const RegisterPage()),
      ),
      GoRoute(
        path: '/verify-email',
        pageBuilder: (_, state) => _authSlideTransition(
          state,
          VerifyEmailPage(email: state.uri.queryParameters['email'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const ForgotPasswordPage()),
      ),
      GoRoute(
        path: '/reset-password',
        pageBuilder: (_, state) => _authSlideTransition(
          state,
          ResetPasswordPage(token: state.uri.queryParameters['token'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/account-deletion-scheduled',
        pageBuilder: (context, state) {
          // Read the deletion date from the live auth state
          final authState = ProviderScope.containerOf(context)
              .read(authNotifierProvider)
              .valueOrNull;
          final deleteAt = authState is AuthAccountDeletionScheduled
              ? authState.scheduledDeleteAt
              : DateTime.now().add(const Duration(days: 5));
          return _authSlideTransition(
            state,
            AccountDeletionScheduledPage(scheduledDeleteAt: deleteAt),
          );
        },
      ),
      // ── Legal routes (viewer + acceptance gate) ───────────────────────────────
      GoRoute(
        path: '/accept-policy',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const PolicyAcceptancePage()),
      ),
      GoRoute(
        path: '/privacy-policy',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const PrivacyPolicyPage()),
      ),
      GoRoute(
        path: '/terms-of-service',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const TermsOfServicePage()),
      ),

      GoRoute(
        path: '/add-transaction',
        pageBuilder: (_, state) => _slideUpTransition(
          state,
          const AddTransactionPage(),
        ),
      ),

      // Full-screen push routes (no bottom nav)
      GoRoute(
        path: '/savings',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const SavingsPage()),
      ),
      GoRoute(
        path: '/wishlist',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const WishlistPage()),
      ),
      GoRoute(
        path: '/categories',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const CategoriesPage()),
      ),
      GoRoute(
        path: '/recurring',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const RecurringPage()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const ProfilePage()),
      ),
      GoRoute(
        path: '/analytics',
        pageBuilder: (_, state) =>
            _authSlideTransition(state, const AnalyticsPage()),
      ),

      // ── Main shell (4 persistent tabs) ────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          // Branch 0 — Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                pageBuilder: (_, state) =>
                    _noTransition(state, const HomePage()),
              ),
            ],
          ),
          // Branch 1 — History (Transactions + Dues)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                pageBuilder: (_, state) =>
                    _noTransition(state, const TransactionsPage()),
              ),
            ],
          ),
          // Branch 2 — Dues
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dues',
                pageBuilder: (_, state) =>
                    _noTransition(state, const DuesPage()),
              ),
            ],
          ),
          // Branch 3 — More (hub)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                pageBuilder: (_, state) =>
                    _noTransition(state, const MorePage()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ─── Page transition helpers ──────────────────────────────────────────────────

/// Standard auth route transition: new page slides in from right,
/// current page slides slightly left when being covered (like iOS stack push).
CustomTransitionPage<void> _authSlideTransition(
    GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    transitionsBuilder: (_, animation, secondaryAnimation, c) {
      // This page: slides in from the right
      final slideIn = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      ));

      // This page: slides slightly left when another page is pushed on top
      final slideOut = Tween(
        begin: Offset.zero,
        end: const Offset(-0.25, 0.0),
      ).animate(CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInOutCubic,
      ));

      return SlideTransition(
        position: secondaryAnimation.status != AnimationStatus.dismissed
            ? slideOut
            : slideIn,
        child: c,
      );
    },
  );
}

CustomTransitionPage<void> _slideUpTransition(
    GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, anim, ___, c) => SlideTransition(
      position: Tween(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: c,
    ),
  );
}

NoTransitionPage<void> _noTransition(GoRouterState state, Widget child) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}


