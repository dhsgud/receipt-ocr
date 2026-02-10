import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LiquidBottomBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const LiquidBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Liquid/Glass colors configuration
    final backgroundColor = isDark 
        ? Colors.black.withOpacity(0.3) 
        : Colors.white.withOpacity(0.3);
        
    final borderColor = isDark 
        ? Colors.white.withOpacity(0.1) 
        : Colors.white.withOpacity(0.6);

    return Padding(
      // Bottom padding handles safe area automatically if we don't wrap in SafeArea
      // But since we want it floating *above* the bottom edge, we add some margin.
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40), // More rounded for "Pill" shape
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Strong blur
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLiquidItem(0, Icons.home_rounded, Icons.home_outlined, '홈', isDark),
                _buildLiquidItem(1, Icons.calendar_month_rounded, Icons.calendar_today_outlined, '캘린더', isDark),
                _LiquidReceiptButton(
                  isSelected: currentIndex == 2,
                  onTap: () => _handleTap(2),
                  isDark: isDark,
                ),
                _buildLiquidItem(3, Icons.pie_chart_rounded, Icons.pie_chart_outline, '통계', isDark),
                _buildLiquidItem(4, Icons.settings_rounded, Icons.settings_outlined, '설정', isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(int index) {
    HapticFeedback.lightImpact(); // Add haptic feedback for premium feel
    onTap(index);
  }

  Widget _buildLiquidItem(
    int index, 
    IconData activeIcon, 
    IconData inactiveIcon, 
    String label, 
    bool isDark,
  ) {
    final isSelected = currentIndex == index;
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5);
    final indicatorColor = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08);

    return Expanded(
      child: GestureDetector(
        onTap: () => _handleTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack, // Bouncy effect
              width: isSelected ? 56 : 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? indicatorColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? activeColor : inactiveColor,
                size: 26,
              ),
            ),
            // Optional: Tiny dot for unselected? Or text for selected?
            // "Liquid" designs often minimalistic. 
            // Let's add a very small scale animation for the label or just skip it for cleaner look.
            // Skipping label for supreme "Ganji" (Style).
          ],
        ),
      ),
    );
  }
}

class _LiquidReceiptButton extends StatefulWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _LiquidReceiptButton({
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_LiquidReceiptButton> createState() => _LiquidReceiptButtonState();
}

class _LiquidReceiptButtonState extends State<_LiquidReceiptButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Special middle button
    final primaryColor = Theme.of(context).primaryColor;
    final iconColor = Colors.white; // Always white for contrast on primary

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        behavior: HitTestBehavior.opaque,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            height: 52, // Slightly larger
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.add_a_photo_rounded,
              color: iconColor,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
