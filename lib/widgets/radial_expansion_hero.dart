import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;

class Photo extends StatelessWidget {
  const Photo({super.key, required this.photo, this.onTap});

  final String photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;

    if (photo.toLowerCase().startsWith('http')) {
      imageProvider = NetworkImage(photo);
    } else if (photo.startsWith('/') || photo.toLowerCase().startsWith('file://')) {
      imageProvider = FileImage(File(photo));
    } else {
      imageProvider = AssetImage(photo);
    }

    return Material(
      color: Theme.of(context).canvasColor.withValues(
        alpha: 0.8,
      ),
      child: InkWell(
        onTap: onTap,
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class RadialExpansion extends StatelessWidget {
  const RadialExpansion({
    super.key,
    required this.maxRadius,
    this.child,
  }) : clipRectSize = 2.0 * (maxRadius / math.sqrt2);

  final double maxRadius;
  final double clipRectSize;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Center(
        child: SizedBox.square(
          dimension: clipRectSize,
          child: ClipRect(child: child),
        ),
      ),
    );
  }
}

class RadialExpansionHero extends StatelessWidget {
  const RadialExpansionHero({
    super.key,
    required this.photo,
    required this.radius,
  });

  final String photo;
  final double radius;

  final Interval opacityCurve = const Interval(0.0, 0.75, curve: Curves.easeInOut);

  static RectTween _createRectTween(Rect? begin, Rect? end) {
    return MaterialRectCenterArcTween(begin: begin, end: end);
  }

  void _expand(BuildContext context, double maxRadius) {
    assert(() {
      timeDilation = 1.5; // Slows down animation in debug mode only
      return true;
    }());

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Opacity(
                opacity: opacityCurve.transform(animation.value),
                child: Center(
                  child: OverflowBox(
                    maxWidth: double.infinity,
                    maxHeight: double.infinity,
                    child: SizedBox.square(
                      dimension: maxRadius * 2.0,
                      child: Hero(
                        createRectTween: _createRectTween,
                        tag: _heroTag,
                        child: RadialExpansion(
                          maxRadius: maxRadius,
                          child: Photo(
                            photo: photo,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String get _heroTag => 'hero:$photo';

  @override
  Widget build(BuildContext context) {
    final maxRadius = (MediaQuery.of(context).size.width * math.sqrt2) / 2.0;

    return SizedBox.square(
      dimension: radius * 2.0,
      child: Hero(
        createRectTween: _createRectTween,
        tag: _heroTag,
        child: RadialExpansion(
          maxRadius: maxRadius,
          child: Photo(
            photo: photo,
            onTap: () => _expand(context, maxRadius),
          ),
        ),
      ),
    );
  }
}
