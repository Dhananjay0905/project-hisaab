/// Spacing scale — 3x multiplier system.
/// Base unit = 4px. Scale: 2, 4, 6, 8, 12, 16, 20, 24, 32, 40, 48, 64
library;

abstract final class AppSpacing {
  static const double xs2 = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xl2 = 24.0;
  static const double xl3 = 32.0;
  static const double xl4 = 40.0;
  static const double xl5 = 48.0;
  static const double xl6 = 64.0;

  // ─── Semantic aliases ─────────────────────────────────────────────────────

  /// Standard horizontal screen padding
  static const double screenH = 20.0;

  /// Standard vertical screen padding
  static const double screenV = 16.0;

  /// Card inner padding
  static const double cardPadding = 20.0;

  /// Space between list items
  static const double listItemGap = 12.0;

  /// Space between section header and its content
  static const double sectionGap = 16.0;

  /// Gap between a label and its value
  static const double labelGap = 4.0;

  /// Floating bottom nav height
  static const double bottomNavHeight = 72.0;

  /// Safe bottom padding for bottom nav
  static const double bottomSafeArea = 12.0;
}

/// Border radius scale — from the Stitch design system (DEFAULT: 16px).
abstract final class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0; // DEFAULT
  static const double xl = 24.0;
  static const double xl2 = 32.0;
  static const double xl3 = 48.0;
  static const double full = 9999.0;
}
