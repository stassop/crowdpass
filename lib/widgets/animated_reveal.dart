import 'package:flutter/material.dart';

class AnimatedReveal extends StatelessWidget {
  final Widget child;
  final bool isOpen;
  final Axis axis;
  final Duration duration;
  final Curve curve;

  const AnimatedReveal({
    super.key,
    required this.child,
    required this.isOpen,
    this.axis = Axis.vertical,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedAlign(
      duration: duration,
      curve: curve,
      alignment: Alignment.topLeft,
      // Setting heightFactor to 0.0 makes the layout size 0, 
      // but the child will still paint if we don't clip it.
      heightFactor: axis == Axis.vertical ? (isOpen ? 1.0 : 0.0) : 1.0,
      widthFactor: axis == Axis.horizontal ? (isOpen ? 1.0 : 0.0) : 1.0,
      
      // We use a transparent placeholder or Visibility to 
      // truly "hide" it from semantics/hit testing when closed.
      child: AnimatedOpacity(
        opacity: isOpen ? 1.0 : 0.0,
        duration: duration,
        child: child,
      ),
    );
  }
}