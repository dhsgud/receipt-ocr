import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _pulseController;
  late AnimationController _particleController;

  // Animations
  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleOpacity;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _glowOpacity;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();

    // Main sequence controller (total ~3 seconds)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Continuous pulse for glow effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Particle float animation
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Icon: appear with bounce scale (0.0s ~ 0.8s)
    _iconScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.35),
    ));

    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.15, curve: Curves.easeOut)),
    );

    // Glow effect (0.1s ~ 0.5s)
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.1, 0.4, curve: Curves.easeOut)),
    );

    // Title: "김동한 가계부" (0.3s ~ 0.6s)
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.25, 0.5, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.25, 0.55, curve: Curves.easeOutCubic)),
    );

    // Subtitle (0.45s ~ 0.7s)
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.6, curve: Curves.easeOut)),
    );
    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.4, 0.65, curve: Curves.easeOutCubic)),
    );

    // Fade out everything (0.85 ~ 1.0)
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.85, 1.0, curve: Curves.easeInCubic)),
    );

    _mainController.forward();
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : const Color(0xFF0D1117);

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _pulseController, _particleController]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _fadeOut,
            child: Stack(
              children: [
                // Animated gradient background
                _buildAnimatedBackground(),
                // Floating particles
                ..._buildParticles(),
                // Main content
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing icon
                      _buildGlowingIcon(),
                      const SizedBox(height: 32),
                      // Title
                      _buildTitle(),
                      const SizedBox(height: 12),
                      // Subtitle
                      _buildSubtitle(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GradientBackgroundPainter(
          progress: _mainController.value,
          pulseValue: _pulseController.value,
        ),
      ),
    );
  }

  Widget _buildGlowingIcon() {
    return Opacity(
      opacity: _iconOpacity.value,
      child: Transform.scale(
        scale: _iconScale.value,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring
            Opacity(
              opacity: _glowOpacity.value * (0.3 + 0.2 * _pulseController.value),
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.4),
                      AppColors.accent.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Inner glow
            Opacity(
              opacity: _glowOpacity.value * (0.5 + 0.3 * _pulseController.value),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      blurRadius: 40,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            // Icon container
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7C6CF0),
                    Color(0xFF6C5CE7),
                    Color(0xFF5341D6),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return SlideTransition(
      position: _titleSlide,
      child: FadeTransition(
        opacity: _titleOpacity,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Colors.white,
              Color(0xFFE0D4FF),
              Colors.white,
            ],
          ).createShader(bounds),
          child: const Text(
            '김동한 가계부',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return SlideTransition(
      position: _subtitleSlide,
      child: FadeTransition(
        opacity: _subtitleOpacity,
        child: Text(
          '스마트한 가계부 관리',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildParticles() {
    final random = Random(42); // Fixed seed for consistency
    return List.generate(20, (index) {
      final startX = random.nextDouble();
      final startY = random.nextDouble();
      final size = 2.0 + random.nextDouble() * 4;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final delay = random.nextDouble();

      return Positioned(
        left: MediaQuery.of(context).size.width * startX,
        top: MediaQuery.of(context).size.height *
            ((startY + _particleController.value * speed + delay) % 1.2 - 0.1),
        child: Opacity(
          opacity: (_glowOpacity.value * (0.2 + 0.3 * sin(_particleController.value * pi * 2 + delay * pi * 2)))
              .clamp(0.0, 1.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index % 3 == 0
                  ? AppColors.primary.withValues(alpha: 0.8)
                  : index % 3 == 1
                      ? AppColors.accent.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.5),
              boxShadow: [
                BoxShadow(
                  color: (index % 3 == 0 ? AppColors.primary : AppColors.accent)
                      .withValues(alpha: 0.4),
                  blurRadius: size * 2,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _GradientBackgroundPainter extends CustomPainter {
  final double progress;
  final double pulseValue;

  _GradientBackgroundPainter({required this.progress, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    // Base dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D1117),
    );

    // Animated radial gradient (top-left, primary)
    final center1 = Offset(
      size.width * (0.2 + 0.1 * sin(progress * pi)),
      size.height * (0.3 + 0.05 * cos(progress * pi)),
    );
    canvas.drawCircle(
      center1,
      size.width * (0.5 + 0.1 * pulseValue),
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15 + 0.05 * pulseValue),
            AppColors.primary.withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center1, radius: size.width * 0.6)),
    );

    // Animated radial gradient (bottom-right, accent)
    final center2 = Offset(
      size.width * (0.8 - 0.1 * sin(progress * pi)),
      size.height * (0.7 - 0.05 * cos(progress * pi)),
    );
    canvas.drawCircle(
      center2,
      size.width * (0.4 + 0.1 * pulseValue),
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.1 + 0.05 * pulseValue),
            AppColors.accent.withValues(alpha: 0.03),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center2, radius: size.width * 0.5)),
    );
  }

  @override
  bool shouldRepaint(covariant _GradientBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.pulseValue != pulseValue;
  }
}
