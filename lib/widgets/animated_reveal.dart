import 'package:flutter/material.dart';

class AnimatedReveal extends StatefulWidget {
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
  State<AnimatedReveal> createState() => _AnimatedRevealState();
}

class _AnimatedRevealState extends State<AnimatedReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    if (widget.isOpen) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant AnimatedReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != oldWidget.isOpen) {
      widget.isOpen ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the standard vertical displacement for floating labels 
    // from the theme to avoid hardcoding "magic numbers".
    final theme = Theme.of(context);
    final double labelBuffer = theme.inputDecorationTheme.isDense == true ? 4.0 : 8.0;

    return SizeTransition(
      sizeFactor: _animation,
      axis: widget.axis,
      axisAlignment: -1.0,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: widget.axis,
        child: widget.axis == Axis.vertical 
          ? IntrinsicHeight(
              child: Padding(
                // Dynamically apply buffer only to the top if vertical
                padding: EdgeInsets.only(top: labelBuffer),
                child: widget.child,
              ),
            )
          : IntrinsicWidth(
              child: widget.child,
            ),
      ),
    );
  }
}