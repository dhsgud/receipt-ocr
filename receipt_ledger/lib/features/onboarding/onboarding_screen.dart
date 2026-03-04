import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_data.dart';

/// SharedPreferences 키
const String kOnboardingCompleted = 'onboarding_completed';

/// 온보딩 완료 여부 확인
Future<bool> isOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kOnboardingCompleted) ?? false;
}

/// 온보딩 튜토리얼 화면
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _bgController;
  late AnimationController _contentController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kOnboardingCompleted, true);
    widget.onComplete();
  }

  void _nextPage() {
    if (_currentPage < onboardingPages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _contentController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final page = onboardingPages[_currentPage];

    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) => Stack(
          children: [
            // Animated background
            _buildBackground(isDark, page.color),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Skip button
                  if (_currentPage < onboardingPages.length - 1)
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            '건너뛰기',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.5)
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),

                  // Page content
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: onboardingPages.length,
                      itemBuilder: (context, index) {
                        return _buildPage(onboardingPages[index], isDark);
                      },
                    ),
                  ),

                  // Bottom navigation
                  _buildBottomNav(isDark),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(bool isDark, Color accentColor) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _OnboardingBgPainter(
          progress: _bgController.value,
          isDark: isDark,
          accentColor: accentColor,
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, bool isDark) {
    return AnimatedBuilder(
      animation: _contentController,
      builder: (context, _) {
        final fadeIn = CurvedAnimation(
          parent: _contentController,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
        );
        final slideUp = CurvedAnimation(
          parent: _contentController,
          curve: const Interval(0.1, 0.6, curve: Curves.easeOutCubic),
        );
        final featuresIn = CurvedAnimation(
          parent: _contentController,
          curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Icon
              Opacity(
                opacity: fadeIn.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - slideUp.value)),
                  child: _buildIcon(page),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Opacity(
                opacity: fadeIn.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - slideUp.value)),
                  child: Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Opacity(
                opacity: fadeIn.value,
                child: Text(
                  page.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Feature cards
              Opacity(
                opacity: featuresIn.value,
                child: Transform.translate(
                  offset: Offset(0, 30 * (1 - featuresIn.value)),
                  child: Column(
                    children: page.features.asMap().entries.map((entry) {
                      return _buildFeatureCard(
                        entry.value,
                        page.color,
                        isDark,
                        entry.key,
                      );
                    }).toList(),
                  ),
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon(OnboardingPage page) {
    return Stack(
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
                page.color.withValues(alpha: 0.25),
                page.color.withValues(alpha: 0.05),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Icon container
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                page.color,
                page.color.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: page.color.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            page.icon,
            size: 42,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    OnboardingFeature feature,
    Color accentColor,
    bool isDark,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : accentColor.withValues(alpha: 0.15),
          width: 0.5,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                feature.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    final isLast = _currentPage == onboardingPages.length - 1;
    final page = onboardingPages[_currentPage];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(onboardingPages.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? page.color
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 28),

          // Next / Start button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: page.color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? '시작하기' : '다음',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (!isLast) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                  if (isLast) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.rocket_launch_rounded, size: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated background painter
class _OnboardingBgPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  final Color accentColor;

  _OnboardingBgPainter({
    required this.progress,
    required this.isDark,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      // Dark background
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = AppColors.backgroundDark,
      );

      // Accent orb (top)
      final c1 = Offset(
        size.width * (0.3 + 0.15 * sin(progress * pi * 2)),
        size.height * (0.15 + 0.05 * cos(progress * pi * 2)),
      );
      canvas.drawCircle(
        c1,
        size.width * 0.5,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accentColor.withValues(alpha: 0.1),
              accentColor.withValues(alpha: 0.02),
              Colors.transparent,
            ],
          ).createShader(
              Rect.fromCircle(center: c1, radius: size.width * 0.5)),
      );

      // Secondary orb (bottom)
      final c2 = Offset(
        size.width * (0.7 - 0.1 * cos(progress * pi * 2 + 1)),
        size.height * (0.8 - 0.04 * sin(progress * pi * 2 + 1)),
      );
      canvas.drawCircle(
        c2,
        size.width * 0.4,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ).createShader(
              Rect.fromCircle(center: c2, radius: size.width * 0.4)),
      );
    } else {
      // Light background
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

      // Accent circle
      final c1 = Offset(
        size.width * (0.2 + 0.15 * sin(progress * pi * 2)),
        size.height * (0.2 + 0.05 * cos(progress * pi * 2)),
      );
      canvas.drawCircle(
        c1,
        size.width * 0.45,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accentColor.withValues(alpha: 0.06),
              Colors.transparent,
            ],
          ).createShader(
              Rect.fromCircle(center: c1, radius: size.width * 0.45)),
      );

      final c2 = Offset(
        size.width * (0.85 - 0.1 * cos(progress * pi * 2)),
        size.height * (0.75 + 0.04 * sin(progress * pi * 2)),
      );
      canvas.drawCircle(
        c2,
        size.width * 0.35,
        Paint()
          ..shader = RadialGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          ).createShader(
              Rect.fromCircle(center: c2, radius: size.width * 0.35)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardingBgPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.accentColor != accentColor;
  }
}
