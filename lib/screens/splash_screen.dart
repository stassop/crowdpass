import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:crowdpass/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _zoomController;

  late Animation<double> _crowdSlide;
  late Animation<double> _passSlide;
  late Animation<double> _rotation;
  late Animation<double> _zoom;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    // Slower duration for a more premium feel
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Rotation: Starts shortly after sliding begins (0.15)
    // and ends at 1.0. One full rotation (-1) is slower than two.
    _rotation = Tween<double>(begin: 0, end: -1).animate(
      CurvedAnimation(
        parent: _introController,
        // Start at 0.4 so it waits for the slide to finish
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic), 
      ),
    );

    _zoom = Tween<double>(begin: 1.0, end: 10.0).animate(
      CurvedAnimation(parent: _zoomController, curve: Curves.easeOutCubic),
    );
    
    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _zoomController, curve: const Interval(0.4, 1.0)),
    );

    _play();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenHeight = MediaQuery.of(context).size.height;

    // Slide completes earlier (0.4) so the spin dominates the second half
    _crowdSlide = Tween<double>(begin: -screenHeight, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInCubic),
      ),
    );

    _passSlide = Tween<double>(begin: screenHeight, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInCubic),
      ),
    );
  }

  Future<void> _play() async {
    await _introController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _zoomController.forward();
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => const HomeScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.displayLarge?.copyWith(
      color: theme.colorScheme.onPrimary,
      fontFamily: 'Unbounded',
      fontWeight: FontWeight.bold,
      letterSpacing: -1.0,
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      // 1. Added horizontal padding to ensure 16 units on sides
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Center(
          // 2. Added FittedBox to prevent RenderFlex overflow
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedBuilder(
              animation: Listenable.merge([_introController, _zoomController]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _zoom.value,
                  child: Opacity(
                    opacity: _opacity.value,
                    child: Transform.rotate(
                      angle: _rotation.value * 2 * math.pi,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(0, _crowdSlide.value),
                            child: Text('Crowd', style: textStyle),
                          ),
                          Transform.translate(
                            offset: Offset(0, _passSlide.value),
                            child: Text('Pass', style: textStyle),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}