/// Scholar Spark / Kinetic Softness design system — Hisaab color tokens.
///
/// Primary override: #3861FB (brand blue)
/// These are mapped from the Stitch design_system.json.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ─── Primary ─────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF3861FB);
  static const Color onPrimary = Color(0xFFF2F1FF);
  static const Color primaryContainer = Color(0xFF849AFF);
  static const Color onPrimaryContainer = Color(0xFF001966);

  // ─── Secondary (Green) ───────────────────────────────────────────────────
  static const Color secondary = Color(0xFF006A28);
  static const Color onSecondary = Color(0xFFCFFFCE);
  static const Color secondaryContainer = Color(0xFF5CFD80);
  static const Color onSecondaryContainer = Color(0xFF005D22);

  // ─── Tertiary (Amber) ────────────────────────────────────────────────────
  static const Color tertiary = Color(0xFF7E5200);
  static const Color onTertiary = Color(0xFFFFF0E2);
  static const Color tertiaryContainer = Color(0xFFFEAA00);
  static const Color onTertiaryContainer = Color(0xFF503300);

  // ─── Error (Red) ─────────────────────────────────────────────────────────
  static const Color error = Color(0xFFB41340);
  static const Color onError = Color(0xFFFFEFEF);
  static const Color errorContainer = Color(0xFFF74B6D);
  static const Color onErrorContainer = Color(0xFF510017);

  // ─── Surface & Background ────────────────────────────────────────────────
  static const Color surface = Color(0xFFF5F6FB);
  static const Color onSurface = Color(0xFF2C2F33);
  static const Color surfaceVariant = Color(0xFFDADDE4);
  static const Color onSurfaceVariant = Color(0xFF595C60);

  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF1F6);
  static const Color surfaceContainer = Color(0xFFE6E8EE);
  static const Color surfaceContainerHigh = Color(0xFFE0E2E9);
  static const Color surfaceContainerHighest = Color(0xFFDADDE4);

  // ─── Outline ─────────────────────────────────────────────────────────────
  static const Color outline = Color(0xFF75777B);
  static const Color outlineVariant = Color(0xFFABADB2);

  // ─── Semantic aliases ────────────────────────────────────────────────────
  /// Cash In transactions — green tint
  static const Color cashIn = Color(0xFF006A28);
  static const Color cashInContainer = Color(0xFFCFFFCE);
  static const Color cashInSurface = Color(0xFFECFFF0);

  /// Cash Out transactions — red/error tint
  static const Color cashOut = Color(0xFFB41340);
  static const Color cashOutContainer = Color(0xFFFFEFEF);
  static const Color cashOutSurface = Color(0xFFFFF0F2);

  /// Dues / Pending — amber tint
  static const Color pending = Color(0xFF7E5200);
  static const Color pendingContainer = Color(0xFFFFF0E2);
  static const Color pendingSurface = Color(0xFFFFF8EC);

  // ─── Gradients ──────────────────────────────────────────────────────────
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3861FB), Color(0xFF849AFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF1549E5), Color(0xFF3861FB), Color(0xFF849AFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  static const Gradient backgroundGradient = RadialGradient(
    center: Alignment(0.0, -0.6),
    radius: 1.2,
    colors: [Color(0xFFDDE4FF), Color(0xFFF5F6FB)],
  );

  static const Gradient cashInGradient = LinearGradient(
    colors: [Color(0xFF006A28), Color(0xFF5CFD80)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient cashOutGradient = LinearGradient(
    colors: [Color(0xFFB41340), Color(0xFFF74B6D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadows ─────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF3861FB).withValues(alpha: 0.10),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF2C2F33).withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Dark Mode Tokens
// ═══════════════════════════════════════════════════════════════════════════════

abstract final class AppColorsDark {
  // ─── Primary ─────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF7B93E8);        // muted periwinkle — easy on dark bg
  static const Color onPrimary = Color(0xFF0D1A4A);      // deep navy text on primary
  static const Color primaryContainer = Color(0xFF1E3270); // deep navy container
  static const Color onPrimaryContainer = Color(0xFFCDD8FF); // pale lavender on container

  // ─── Secondary (Green) ───────────────────────────────────────────────────
  static const Color secondary = Color(0xFF7ADB8E);
  static const Color onSecondary = Color(0xFF003913);
  static const Color secondaryContainer = Color(0xFF005D22);
  static const Color onSecondaryContainer = Color(0xFFCFFFCE);

  // ─── Tertiary (Amber) ────────────────────────────────────────────────────
  static const Color tertiary = Color(0xFFFFBE44);
  static const Color onTertiary = Color(0xFF3D2600);
  static const Color tertiaryContainer = Color(0xFF5D3F00);
  static const Color onTertiaryContainer = Color(0xFFFFE0A0);

  // ─── Error (Red) ─────────────────────────────────────────────────────────
  static const Color error = Color(0xFFFF8A9C);
  static const Color onError = Color(0xFF510017);
  static const Color errorContainer = Color(0xFF8C0A2E);
  static const Color onErrorContainer = Color(0xFFFFDADF);

  // ─── Surface & Background ────────────────────────────────────────────────
  static const Color surface = Color(0xFF121417);
  static const Color onSurface = Color(0xFFE4E6EB);
  static const Color surfaceVariant = Color(0xFF3A3D42);
  static const Color onSurfaceVariant = Color(0xFFA0A3A8);

  static const Color surfaceContainerLowest = Color(0xFF1A1D21);
  static const Color surfaceContainerLow = Color(0xFF1F2228);
  static const Color surfaceContainer = Color(0xFF262A30);
  static const Color surfaceContainerHigh = Color(0xFF2D3138);
  static const Color surfaceContainerHighest = Color(0xFF353940);

  // ─── Outline ─────────────────────────────────────────────────────────────
  static const Color outline = Color(0xFF6E7075);
  static const Color outlineVariant = Color(0xFF454850);

  // ─── Semantic aliases ────────────────────────────────────────────────────
  static const Color cashIn = Color(0xFF7ADB8E);
  static const Color cashInContainer = Color(0xFF1B3D24);
  static const Color cashInSurface = Color(0xFF132A1A);

  static const Color cashOut = Color(0xFFE87B8F);  // softened rose — less neon than #FF8A9C
  static const Color cashOutContainer = Color(0xFF3D1520);
  static const Color cashOutSurface = Color(0xFF2A0F16);

  static const Color pending = Color(0xFFFFBE44);
  static const Color pendingContainer = Color(0xFF3D2600);
  static const Color pendingSurface = Color(0xFF2A1A00);

  // ─── Gradients ──────────────────────────────────────────────────────────
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3A5CC5), Color(0xFF6B85D8)],   // deep royal → soft periwinkle
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient heroCardGradient = LinearGradient(
    colors: [Color(0xFF1A2E6E), Color(0xFF2E4BAD), Color(0xFF6B85D8)], // deep navy → muted periwinkle
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.5, 1.0],
  );

  static const Gradient backgroundGradient = RadialGradient(
    center: Alignment(0.0, -0.6),
    radius: 1.2,
    colors: [Color(0xFF1A2040), Color(0xFF121417)],
  );

  static const Gradient cashInGradient = LinearGradient(
    colors: [Color(0xFF005D22), Color(0xFF7ADB8E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient cashOutGradient = LinearGradient(
    colors: [Color(0xFF8C0A2E), Color(0xFFFF8A9C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Shadows ─────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.30),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.20),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];
}
