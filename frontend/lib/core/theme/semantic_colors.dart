/// SemanticColors — ThemeExtension for income/expense color tokens.
///
/// Two variants:
///   • [SemanticColors.normal]     — standard green / red palette.
///   • [SemanticColors.colorblind] — blue / orange palette for
///     deuteranopia / protanopia (can't distinguish red & green).
///
/// Access anywhere: `SemanticColors.of(context).cashIn`
library;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.cashIn,
    required this.cashInContainer,
    required this.cashInSurface,
    required this.cashOut,
    required this.cashOutContainer,
    required this.cashOutSurface,
    required this.cashInGradient,
    required this.cashOutGradient,
  });

  final Color cashIn;
  final Color cashInContainer;
  final Color cashInSurface;
  final Color cashOut;
  final Color cashOutContainer;
  final Color cashOutSurface;
  final Gradient cashInGradient;
  final Gradient cashOutGradient;

  // ─── Normal (green / red) ─────────────────────────────────────────────────

  static const SemanticColors normal = SemanticColors(
    cashIn: AppColors.cashIn,
    cashInContainer: AppColors.cashInContainer,
    cashInSurface: AppColors.cashInSurface,
    cashOut: AppColors.cashOut,
    cashOutContainer: AppColors.cashOutContainer,
    cashOutSurface: AppColors.cashOutSurface,
    cashInGradient: AppColors.cashInGradient,
    cashOutGradient: AppColors.cashOutGradient,
  );

  // ─── Colorblind (blue / orange) ───────────────────────────────────────────
  // Chosen for deuteranopia / protanopia — blue and orange are maximally
  // distinct even without colour discrimination.

  static const SemanticColors colorblind = SemanticColors(
    cashIn: Color(0xFF0057B8),           // vivid blue  — income
    cashInContainer: Color(0xFFCCE4FF),  // light blue
    cashInSurface: Color(0xFFEBF4FF),    // very light blue
    cashOut: Color(0xFFCC5500),          // burnt orange — expense
    cashOutContainer: Color(0xFFFFE5CC), // light orange
    cashOutSurface: Color(0xFFFFF3E6),   // very light orange
    cashInGradient: LinearGradient(
      colors: [Color(0xFF0057B8), Color(0xFF5BA3F5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    cashOutGradient: LinearGradient(
      colors: [Color(0xFFCC5500), Color(0xFFFF8C42)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  // ─── Accessor ─────────────────────────────────────────────────────────────

  /// Fetch the current [SemanticColors] from the nearest [Theme].
  /// Falls back to [normal] if no extension is registered.
  static SemanticColors of(BuildContext context) =>
      Theme.of(context).extension<SemanticColors>() ?? normal;

  // ─── ThemeExtension overrides ─────────────────────────────────────────────

  @override
  SemanticColors copyWith({
    Color? cashIn,
    Color? cashInContainer,
    Color? cashInSurface,
    Color? cashOut,
    Color? cashOutContainer,
    Color? cashOutSurface,
    Gradient? cashInGradient,
    Gradient? cashOutGradient,
  }) {
    return SemanticColors(
      cashIn: cashIn ?? this.cashIn,
      cashInContainer: cashInContainer ?? this.cashInContainer,
      cashInSurface: cashInSurface ?? this.cashInSurface,
      cashOut: cashOut ?? this.cashOut,
      cashOutContainer: cashOutContainer ?? this.cashOutContainer,
      cashOutSurface: cashOutSurface ?? this.cashOutSurface,
      cashInGradient: cashInGradient ?? this.cashInGradient,
      cashOutGradient: cashOutGradient ?? this.cashOutGradient,
    );
  }

  @override
  SemanticColors lerp(SemanticColors? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      cashIn: Color.lerp(cashIn, other.cashIn, t)!,
      cashInContainer: Color.lerp(cashInContainer, other.cashInContainer, t)!,
      cashInSurface: Color.lerp(cashInSurface, other.cashInSurface, t)!,
      cashOut: Color.lerp(cashOut, other.cashOut, t)!,
      cashOutContainer:
          Color.lerp(cashOutContainer, other.cashOutContainer, t)!,
      cashOutSurface: Color.lerp(cashOutSurface, other.cashOutSurface, t)!,
      // Gradients don't lerp cleanly — just pick the target at t≥0.5
      cashInGradient: t < 0.5 ? cashInGradient : other.cashInGradient,
      cashOutGradient: t < 0.5 ? cashOutGradient : other.cashOutGradient,
    );
  }
}
