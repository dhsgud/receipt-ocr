import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _entryController;
  late AnimationController _particleController;

  late Animation<double> _iconScale;
  late Animation<double> _iconOpacity;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _featuresOpacity;
  late Animation<double> _buttonOpacity;
  late Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _iconOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.0, 0.4, curve: Curves.elasticOut)),
    );
    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.2, 0.5, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.2, 0.55, curve: Curves.easeOutCubic)),
    );
    _featuresOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.4, 0.7, curve: Curves.easeOut)),
    );
    _buttonOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.6, 0.85, curve: Curves.easeOut)),
    );
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _entryController, curve: const Interval(0.6, 0.9, curve: Curves.easeOutCubic)),
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _entryController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context, ) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_bgController, _entryController, _particleController]),
        builder: (context, _) {
          return Stack(
            children: [
              // Animated background
              _buildBackground(isDark),
              // Floating particles
              ..._buildParticles(),
              // Main content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      // App icon with glow
                      _buildAppIcon(),
                      const SizedBox(height: 28),
                      // Title & subtitle
                      _buildTitleSection(),
                      const SizedBox(height: 48),
                      // Feature highlights
                      _buildFeatureCards(),
                      const Spacer(flex: 2),
                      // Error message
                      if (authState.error != null)
                        _buildErrorMessage(authState.error!),
                      // Google Sign-In Button
                      _buildGoogleSignInButton(authState),
                      const SizedBox(height: 16),
                      // Terms
                      _buildTermsNotice(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _LoginBackgroundPainter(
          progress: _bgController.value,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildAppIcon() {
    return Opacity(
      opacity: _iconOpacity.value,
      child: Transform.scale(
        scale: _iconScale.value,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Glow
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.accent.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Icon
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8B7CF6),
                    Color(0xFF6C5CE7),
                    Color(0xFF5341D6),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return SlideTransition(
      position: _titleSlide,
      child: FadeTransition(
        opacity: _titleOpacity,
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppColors.textPrimaryLight,
                  AppColors.primary,
                ],
              ).createShader(bounds),
              child: Text(
                '김동한 가계부',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '영수증 분석으로 간편하게 가계부 관리',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.5)
                    : AppColors.textSecondaryLight,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCards() {
    return FadeTransition(
      opacity: _featuresOpacity,
      child: Row(
        children: [
          Expanded(child: _featureCard(Icons.camera_alt_rounded, '영수증 촬영', const Color(0xFF6C5CE7))),
          const SizedBox(width: 12),
          Expanded(child: _featureCard(Icons.auto_awesome_rounded, 'AI 자동 분석', const Color(0xFF00CEC9))),
          const SizedBox(width: 12),
          Expanded(child: _featureCard(Icons.bar_chart_rounded, '지출 통계', const Color(0xFF00B894))),
        ],
      ),
    );
  }

  Widget _featureCard(IconData icon, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.8) : AppColors.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.expense.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.expense, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: AppColors.expense,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton(AuthState authState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _buttonSlide,
      child: FadeTransition(
        opacity: _buttonOpacity,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: authState.isLoading
                ? null
                : () => ref.read(authProvider.notifier).signIn(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : Colors.white,
              foregroundColor: Colors.black87,
              elevation: isDark ? 0 : 4,
              shadowColor: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: authState.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google logo
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [
                                    Color(0xFF4285F4),
                                    Color(0xFF34A853),
                                    Color(0xFFFBBC05),
                                    Color(0xFFEA4335),
                                  ],
                                ).createShader(const Rect.fromLTWH(0, 0, 22, 22)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Google로 시작하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsNotice() {
    return FadeTransition(
      opacity: _buttonOpacity,
      child: Text(
        '로그인하면 서비스 이용약관에 동의하게 됩니다',
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.3)
              : AppColors.textTertiaryLight,
        ),
      ),
    );
  }

  List<Widget> _buildParticles() {
    final random = Random(99);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return []; // Skip particles in light mode for cleanliness

    return List.generate(15, (index) {
      final startX = random.nextDouble();
      final startY = random.nextDouble();
      final size = 1.5 + random.nextDouble() * 3;
      final speed = 0.2 + random.nextDouble() * 0.5;
      final delay = random.nextDouble();

      return Positioned(
        left: MediaQuery.of(context).size.width * startX,
        top: MediaQuery.of(context).size.height *
            ((startY + _particleController.value * speed + delay) % 1.2 - 0.1),
        child: Opacity(
          opacity: (0.15 + 0.2 * sin(_particleController.value * pi * 2 + delay * pi * 2))
              .clamp(0.0, 1.0),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index % 2 == 0
                  ? AppColors.primary.withValues(alpha: 0.6)
                  : AppColors.accent.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    });
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _LoginBackgroundPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      // Dark mode: deep dark with subtle animated gradient orbs
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF0D1117),
      );

      // Primary gradient orb (top-left)
      final c1 = Offset(
        size.width * (0.15 + 0.15 * sin(progress * pi * 2)),
        size.height * (0.2 + 0.08 * cos(progress * pi * 2)),
      );
      canvas.drawCircle(
        c1,
        size.width * 0.55,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.03),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c1, radius: size.width * 0.55)),
      );

      // Accent gradient orb (bottom-right)
      final c2 = Offset(
        size.width * (0.85 - 0.1 * sin(progress * pi * 2 + 1)),
        size.height * (0.75 - 0.06 * cos(progress * pi * 2 + 1)),
      );
      canvas.drawCircle(
        c2,
        size.width * 0.45,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.08),
              AppColors.accent.withValues(alpha: 0.02),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c2, radius: size.width * 0.45)),
      );
    } else {
      // Light mode: clean white/lavender gradient with animated mesh
      final bgPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFF3F0FF),
            const Color(0xFFF7F8FC),
            const Color(0xFFEDF8F8),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // Soft animated circles
      final c1 = Offset(
        size.width * (0.1 + 0.15 * sin(progress * pi * 2)),
        size.height * (0.15 + 0.08 * cos(progress * pi * 2)),
      );
      canvas.drawCircle(
        c1,
        size.width * 0.5,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c1, radius: size.width * 0.5)),
      );

      final c2 = Offset(
        size.width * (0.9 - 0.1 * cos(progress * pi * 2)),
        size.height * (0.85 + 0.05 * sin(progress * pi * 2)),
      );
      canvas.drawCircle(
        c2,
        size.width * 0.4,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c2, radius: size.width * 0.4)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LoginBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
