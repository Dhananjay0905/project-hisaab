/// AppShell — wraps the StatefulNavigationShell from go_router
/// with the custom frosted-glass bottom navigation bar.
///
/// On first mount it:
///   1. Prefetches ALL data providers in parallel so every tab is
///      instantly ready when the user navigates (no loading spinners).
///   2. Checks for recurring transactions due today and shows a
///      DueRecurringDialog bottom sheet for each one sequentially.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/categories/presentation/providers/categories_provider.dart';
import '../../features/dashboard/presentation/providers/summary_provider.dart';
import '../../features/dues/presentation/providers/dues_provider.dart';
import '../../features/recurring/presentation/providers/recurring_provider.dart';
import '../../features/recurring/presentation/widgets/due_recurring_dialog.dart';
import '../../features/savings/presentation/providers/savings_provider.dart';
import '../../features/splits/presentation/providers/splits_provider.dart';
import '../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../features/wishlist/presentation/providers/wishlist_provider.dart';
import 'bottom_nav_bar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _dueChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAll();
      _checkDue();
    });
  }

  /// Fire all data providers in parallel immediately after the shell mounts.
  /// Uses fire-and-forget (no await) so the UI is never blocked.
  /// By the time the user taps any tab the futures are already resolving.
  void _prefetchAll() {
    // ignore: unused_result — intentional fire-and-forget warm-up
    ref.read(dashboardSummaryProvider.future);
    ref.read(duesProvider.future);
    ref.read(duesSummaryProvider.future);
    ref.read(savingsProvider.future);
    ref.read(wishlistProvider.future);
    ref.read(recurringProvider.future);
    ref.read(splitsProvider.future);
    ref.read(categoriesProvider.future);
    ref.read(transactionsProvider.future);
  }

  Future<void> _checkDue() async {
    if (_dueChecked || !mounted) return;
    _dueChecked = true;

    try {
      final dueItems = await ref.read(dueRecurringProvider.future);
      for (final item in dueItems) {
        if (!mounted) break;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          isDismissible: true,
          builder: (_) => DueRecurringDialog(item: item),
        );
        // Small gap between sheets if multiple items are due
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {
      // Silently ignore — don't disrupt the main app on a background check failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.shell,
      extendBody: true,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: widget.shell.currentIndex,
        onTabSelected: (index) => widget.shell.goBranch(
          index,
          initialLocation: index == widget.shell.currentIndex,
        ),
        onAddPressed: () => context.push('/add-transaction'),
      ),
    );
  }
}
