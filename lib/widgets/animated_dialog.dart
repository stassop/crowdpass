import 'package:flutter/material.dart';

class AnimatedDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget content,
    bool barrierDismissible = true,
    Widget? title,
    List<Widget>? actions,
    EdgeInsets contentPadding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
    EdgeInsets titlePadding = const EdgeInsets.fromLTRB(16, 24, 16, 8),
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black.withAlpha(127),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(animation);
        final opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(animation);

        return FadeTransition(
          opacity: opacityAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: SimpleDialog(
              title: title,
              titlePadding: titlePadding,
              contentPadding: contentPadding,
              insetPadding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                content,
                if (actions != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 8.0,
                      overflowSpacing: 8.0,
                      children: actions,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
