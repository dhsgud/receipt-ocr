import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 동기화 튜토리얼 배너 위젯
/// 설정 화면에서 처음 동기화 섹션에 접근할 때 표시되는 인라인 가이드
/// 공유키 교환 메커니즘을 사용자 친화적으로 설명
class SyncTutorialBanner extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onSetNickname;
  final VoidCallback onShowQr;
  final VoidCallback onSync;

  const SyncTutorialBanner({
    super.key,
    required this.onDismiss,
    required this.onSetNickname,
    required this.onShowQr,
    required this.onSync,
  });

  @override
  State<SyncTutorialBanner> createState() => _SyncTutorialBannerState();
}

class _SyncTutorialBannerState extends State<SyncTutorialBanner>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      _animController.reverse().then((_) {
        setState(() {
          _currentStep++;
        });
        _animController.forward();
      });
    } else {
      widget.onDismiss();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _animController.reverse().then((_) {
        setState(() {
          _currentStep--;
        });
        _animController.forward();
      });
    }
  }

  void _onStepAction() {
    switch (_currentStep) {
      case 0: // 개요 → 다음으로
        _nextStep();
        break;
      case 1: // 닉네임 설정
        widget.onSetNickname();
        _nextStep();
        break;
      case 2: // 내 키 공유
        widget.onShowQr();
        _nextStep();
        break;
      case 3: // 파트너 키 입력 → 다음으로
        _nextStep();
        break;
      case 4: // 동기화
        widget.onSync();
        widget.onDismiss();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _stepColor.withValues(alpha: 0.12),
              _stepColor.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _stepColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with step indicator
              _buildHeader(),
              const SizedBox(height: 14),

              // Step content
              _buildStepContent(),
              const SizedBox(height: 16),

              // Navigation
              _buildNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Color get _stepColor {
    switch (_currentStep) {
      case 0:
        return Colors.indigo;
      case 1:
        return AppColors.primary;
      case 2:
        return Colors.teal;
      case 3:
        return Colors.orange;
      case 4:
        return AppColors.income;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _stepColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _stepIcon,
            color: _stepColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '📖 가계부 공유 가이드  ${_currentStep + 1}/5',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Step indicator dots
                  ...List.generate(
                    5,
                    (i) => Container(
                      width: i == _currentStep ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(left: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: i == _currentStep
                            ? _stepColor
                            : i < _currentStep
                                ? _stepColor.withValues(alpha: 0.4)
                                : Colors.grey.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _stepTitle,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _stepColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData get _stepIcon {
    switch (_currentStep) {
      case 0:
        return Icons.info_outline;
      case 1:
        return Icons.badge_outlined;
      case 2:
        return Icons.share;
      case 3:
        return Icons.person_add;
      case 4:
        return Icons.sync;
      default:
        return Icons.help_outline;
    }
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return '동기화란?';
      case 1:
        return '1단계: 내 닉네임 설정';
      case 2:
        return '2단계: 내 공유키를 파트너에게 알려주기';
      case 3:
        return '3단계: 파트너의 공유키 입력하기';
      case 4:
        return '4단계: 동기화 실행!';
      default:
        return '';
    }
  }

  String get _stepButtonText {
    switch (_currentStep) {
      case 0:
        return '시작하기';
      case 1:
        return '닉네임 설정';
      case 2:
        return '내 QR 보기';
      case 3:
        return '다음';
      case 4:
        return '동기화하기';
      default:
        return '다음';
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildOverviewStep();
      case 1:
        return _buildNicknameStep();
      case 2:
        return _buildShareMyKeyStep();
      case 3:
        return _buildEnterPartnerKeyStep();
      case 4:
        return _buildSyncStep();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Step 0: 동기화 개요 설명
  Widget _buildOverviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '파트너와 가계부를 함께 관리할 수 있어요!\n'
          '서로의 공유키를 교환하면 데이터가 연결됩니다.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 14),
        // Visual diagram
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildFlowRow(
                '🙋 나',
                '내 공유키 전달 →',
                '👫 파트너',
                Colors.teal,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '파트너가 내 키를 입력하면\n→ 파트너가 나의 가계부를 볼 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                ),
              ),
              const Divider(height: 16),
              _buildFlowRow(
                '👫 파트너',
                '← 파트너 공유키 전달',
                '🙋 나',
                Colors.orange,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '내가 파트너의 키를 입력하면\n→ 내가 파트너의 가계부를 볼 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Text('💡', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '양쪽 모두 상대방의 키를 입력해야 서로의 데이터를 볼 수 있어요!',
                  style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlowRow(String left, String middle, String right, Color arrowColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(left, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              middle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: arrowColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(right, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  /// Step 1: 닉네임 설정
  Widget _buildNicknameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '파트너의 가계부에서 내 거래가 어떤 이름으로\n표시될지 설정해요.',
          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Text('☕', style: TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('카페 라떼', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        SizedBox(width: 6),
                        _ExampleChip(label: '동한', isPrimary: true),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text('카페 • 14:30', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Text(
                '-4,500원',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            '↑ 닉네임이 거래 옆에 이렇게 표시돼요',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  /// Step 2: 내 공유키 파트너에게 알려주기
  Widget _buildShareMyKeyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
            children: [
              const TextSpan(text: '파트너가 '),
              TextSpan(
                text: '나의 가계부',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.teal[400],
                ),
              ),
              const TextSpan(text: '를 보려면,\n내 공유키를 파트너에게 알려줘야 해요.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            children: [
              Row(
                children: [
                  Text('📱', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'QR 코드를 보여주거나\n키를 복사해서 메시지로 보내세요',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: Colors.teal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '파트너가 이 키를 입력하면 → 나의 데이터가 공유됨',
                  style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Step 3: 파트너의 공유키 입력
  Widget _buildEnterPartnerKeyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
            children: [
              const TextSpan(text: '내가 '),
              TextSpan(
                text: '파트너의 가계부',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.orange[400],
                ),
              ),
              const TextSpan(text: '를 보려면,\n파트너의 공유키를 받아서 입력해야 해요.'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            children: [
              Row(
                children: [
                  Text('🔑', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '아래 "파트너 추가" 버튼에서\n파트너에게 받은 공유키를 입력하세요',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '파트너의 키를 입력하면 → 파트너의 데이터를 받을 수 있음',
                  style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Step 4: 동기화 실행
  Widget _buildSyncStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '모든 준비 완료! 🎉\n동기화 버튼을 누르면 서로의 가계부가 합쳐져요.',
          style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.income.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSyncResultRow('🙋 나의 거래', '파트너에게 전송됨', Colors.teal),
              const SizedBox(height: 8),
              _buildSyncResultRow('👫 파트너 거래', '나에게 전송됨', Colors.orange),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: AppColors.income),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '이후에는 원할 때마다 동기화 버튼으로\n최신 데이터를 주고받을 수 있어요',
                      style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncResultRow(String label, String result, Color color) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        Icon(Icons.arrow_forward, size: 14, color: color),
        const SizedBox(width: 8),
        Text(
          result,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigation() {
    return Row(
      children: [
        if (_currentStep > 0)
          TextButton.icon(
            onPressed: _prevStep,
            icon: const Icon(Icons.arrow_back_ios, size: 14),
            label: const Text('이전'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              textStyle: const TextStyle(fontSize: 13),
            ),
          )
        else
          TextButton(
            onPressed: widget.onDismiss,
            child: const Text(
              '건너뛰기',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _onStepAction,
          icon: Icon(_stepIcon, size: 16),
          label: Text(_stepButtonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: _stepColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}

/// 예시 칩 (닉네임 미리보기)
class _ExampleChip extends StatelessWidget {
  final String label;
  final bool isPrimary;

  const _ExampleChip({required this.label, this.isPrimary = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primary.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isPrimary ? AppColors.primary : Colors.orange,
        ),
      ),
    );
  }
}
