import 'package:flutter/material.dart';

/// A circular icon button with configurable size and colors.
class RoundIconButton extends StatelessWidget {
  final Widget icon;
  final double radius;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final VoidCallback? onPressed;

  /// Base constructor with customizable radius.
  const RoundIconButton({
    super.key,
    required this.icon,
    this.radius = 24,
    this.foregroundColor,
    this.backgroundColor,
    this.onPressed,
  });

  /// Predefined small size (16 radius).
  const RoundIconButton.small({
    super.key,
    required this.icon,
    this.foregroundColor,
    this.backgroundColor,
    this.onPressed,
  }) : radius = 16;

  /// Predefined medium size (24 radius).
  const RoundIconButton.medium({
    super.key,
    required this.icon,
    this.foregroundColor,
    this.backgroundColor,
    this.onPressed,
  }) : radius = 24;

  /// Predefined large size (48 radius).
  const RoundIconButton.large({
    super.key,
    required this.icon,
    this.foregroundColor,
    this.backgroundColor,
    this.onPressed,
  }) : radius = 48.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Center(child: icon),
      ),
    );
  }
}
