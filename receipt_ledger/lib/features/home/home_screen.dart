import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/banner_ad_widget.dart';
import '../../shared/widgets/transaction_dialogs.dart';
import '../../shared/widgets/savings_goal_dialogs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/greeting_messages.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category.dart';
import '../../data/models/savings_goal.dart';
import 'all_transactions_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final String _greeting;

  @override
  void initState() {
    super.initState();
    _greeting = greetingMessages[Random().nextInt(greetingMessages.length)];
  }

  @override
  Widget build(BuildContext context) {
    final monthlyStats = ref.watch(monthlyStatsProvider);
    final selectedDateTransactions = ref.watch(selectedDateTransactionsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 상단 배너 광고
            const SliverToBoxAdapter(child: TopBannerAd()),

            // App Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.month(DateTime.now()),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const NotificationScreen(),
                              ),
                            );
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  top: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.expense,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      unreadCount > 9 ? '9+' : '$unreadCount',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Monthly Summary Card
                    monthlyStats.when(
                      data: (stats) => _buildSummaryCard(stats, isDark),
                      loading: () => Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.cardDark : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 16),

                    // 목표 달성 카드
                    _buildGoalCard(isDark),
                  ],
                ),
              ),
            ),

            // Today's Transactions Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Formatters.dateShort(selectedDate),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AllTransactionsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '전체보기',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Transactions List
            selectedDateTransactions.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: '거래 내역이 없습니다',
                      subtitle: '영수증을 촬영하여 거래를 추가해보세요',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final transaction = transactions[index];
                        final category =
                            Category.findByName(transaction.category);
                        final syncService = ref.read(syncServiceProvider);
                        final ownerName =
                            syncService.getOwnerName(transaction.ownerKey);
                        final isMine =
                            syncService.isMyTransaction(transaction.ownerKey);

                        return TransactionListItem(
                          emoji: category.emoji,
                          title: transaction.description,
                          subtitle:
                              '${transaction.category} • ${Formatters.time(transaction.date)}',
                          amount: Formatters.currency(transaction.amount),
                          isIncome: transaction.isIncome,
                          ownerLabel:
                              syncService.isPaired ? ownerName : null,
                          isMyTransaction: isMine,
                          onTap: () {
                            showTransactionDetailsDialog(
                              context: context,
                              ref: ref,
                              transaction: transaction,
                            );
                          },
                          onLongPress: () {
                            showTransactionMenu(
                              context: context,
                              ref: ref,
                              transaction: transaction,
                            );
                          },
                        );
                      },
                      childCount: transactions.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => const SliverFillRemaining(
                child: Center(child: Text('오류가 발생했습니다')),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(MonthlyStats stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 달 잔액',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Formatters.currency(stats.balance),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  '수입',
                  Formatters.currency(stats.income),
                  Icons.trending_up_rounded,
                  const Color(0xFF55EFC4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStat(
                  '지출',
                  Formatters.currency(stats.expense),
                  Icons.trending_down_rounded,
                  const Color(0xFFFF8E8E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 목표 달성 카드
  Widget _buildGoalCard(bool isDark) {
    final goalProgress = ref.watch(goalProgressProvider);

    return goalProgress.when(
      data: (progress) {
        // 목표가 없으면 설정 유도 카드
        if (progress == null) {
          return _buildGoalEmptyCard(isDark);
        }
        return _buildGoalProgressCard(progress, isDark);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// 목표 미설정 시 CTA 카드
  Widget _buildGoalEmptyCard(bool isDark) {
    return GestureDetector(
      onTap: () => showSavingsGoalDialog(context: context, ref: ref),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flag_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 달 목표를 설정해보세요',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '저축 목표 또는 지출 한도를 설정할 수 있어요',
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
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 목표 프로그레스 카드
  Widget _buildGoalProgressCard(GoalProgress progress, bool isDark) {
    final goal = progress.goal;
    final isSaving = goal.goalType == GoalType.saving;
    final percent = progress.progressPercent.clamp(0, 100).toDouble();
    final isAchieved = progress.isAchieved;

    // 색상 결정
    final Color progressColor;
    if (isAchieved) {
      progressColor = const Color(0xFF00C853);
    } else if (percent >= 70) {
      progressColor = AppColors.primary;
    } else if (percent >= 40) {
      progressColor = const Color(0xFFFFA726);
    } else {
      progressColor = const Color(0xFFEF5350);
    }

    return GestureDetector(
      onTap: () => showSavingsGoalDialog(
        context: context,
        ref: ref,
        existingGoal: goal,
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: progressColor.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 원형 프로그레스
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      value: (percent / 100).clamp(0.0, 1.0),
                      strokeWidth: 6,
                      backgroundColor: progressColor.withValues(alpha: 0.15),
                      color: progressColor,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  if (isAchieved)
                    Icon(
                      Icons.check_rounded,
                      color: progressColor,
                      size: 28,
                    )
                  else
                    Text(
                      '${percent.toInt()}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: progressColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // 텍스트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: progressColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSaving ? '💰 저축 목표' : '🛒 지출 한도',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: progressColor,
                          ),
                        ),
                      ),
                      if (isAchieved) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '달성! 🎉',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00C853),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isSaving
                        ? '${Formatters.currency(progress.currentValue)} / ${Formatters.currency(goal.goalAmount)}'
                        : '${Formatters.currency(progress.currentValue)} / ${Formatters.currency(goal.goalAmount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getGoalSubtitle(progress),
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
      ),
    );
  }

  /// 목표 서브타이틀 생성
  String _getGoalSubtitle(GoalProgress progress) {
    final goal = progress.goal;
    if (goal.goalType == GoalType.saving) {
      final remaining = goal.goalAmount - progress.currentValue;
      if (remaining <= 0) {
        return '목표를 달성했어요! 대단해요 👏';
      }
      return '${Formatters.currency(remaining)} 더 모으면 달성!';
    } else {
      final remaining = goal.goalAmount - progress.expense;
      if (remaining <= 0) {
        return '한도를 ${Formatters.currency(-remaining)} 초과했어요 😥';
      }
      return '${Formatters.currency(remaining)} 남았어요';
    }
  }
}
