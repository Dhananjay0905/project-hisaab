/// Primary gradient CTA button matching Scholar Spark design.
library;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_typography.dart';

class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.gradient,
    this.icon,
    this.height = 54,
    this.width = double.infinity,
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Gradient? gradient;
  final IconData? icon;
  final double height;
  final double width;
  final double? borderRadius;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppSpacing.lg;
    final canPress = widget.onPressed != null && !widget.loading;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveGradient = widget.gradient ??
        (isDark ? AppColorsDark.primaryGradient : AppColors.primaryGradient);

    return GestureDetector(
      onTapDown: canPress ? (_) => _controller.reverse() : null,
      onTapUp: canPress
          ? (_) async {
              await _controller.forward();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: canPress ? () => _controller.forward() : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: canPress ? effectiveGradient : null,
            color: canPress ? null : Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: canPress
                ? (Theme.of(context).brightness == Brightness.dark
                    ? AppColorsDark.cardShadow
                    : AppColors.cardShadow)
                : null,
          ),
          child: widget.loading
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      widget.label,
                      style: AppTypography.labelLarge.copyWith(
                        color: canPress
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Secondary outlined button (no gradient).
class OutlinedAppButton extends StatelessWidget {
  const OutlinedAppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
    this.width = double.infinity,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null
            ? Icon(icon, size: 20)
            : const SizedBox.shrink(),
        label: Text(label),
      ),
    );
  }
}

/// Small icon button with consistent Hisaab styling.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 40,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(size / 2),
          ),
          child: Icon(
            icon,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
