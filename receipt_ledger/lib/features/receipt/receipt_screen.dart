import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction.dart';
import '../../data/models/receipt.dart';
import '../../shared/providers/app_providers.dart';

import '../settings/subscription_screen.dart';
import '../../data/services/purchase_service.dart';
import '../../data/services/quota_service.dart';
import '../../data/services/budget_alert_service.dart';
import '../../data/services/ad_service.dart';
import '../../core/entitlements.dart';

import 'models/batch_receipt_item.dart';
import 'widgets/receipt_form.dart';
import 'widgets/batch_mode_view.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  // 단일 처리 모드
  XFile? _pickedFile;
  Uint8List? _imageBytes;
  bool _isProcessing = false;
  ReceiptData? _receiptData;
  String? _errorMessage;
  bool _showDebugInfo = true; // 디버그 모드 ON/OFF

  // 일괄 처리 모드
  List<BatchReceiptItem> _batchItems = [];
  bool _isBatchMode = false;
  bool _isBatchProcessing = false;

  // OCR 요청 취소용 토큰
  CancelToken? _ocrCancelToken;

  // Form controllers
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  bool _isIncome = false;

  @override
  void dispose() {
    _ocrCancelToken?.cancel('Screen disposed');
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Read bytes for web compatibility
        final bytes = await pickedFile.readAsBytes();
        
        setState(() {
          _pickedFile = pickedFile;
          _imageBytes = bytes;
          _errorMessage = null;
        });
        await _processReceipt();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '이미지를 불러올 수 없습니다: $e';
      });
    }
  }

  Future<void> _processReceipt() async {
    if (_imageBytes == null) return;

    // 구독 상태 확인
    final subscription = ref.read(subscriptionProvider);
    final quotaNotifier = ref.read(quotaProvider.notifier);
    
    // 인증된 사용자의 티어로 사용 가능 여부 확인
    if (!quotaNotifier.canUseOcr(subscription.tier)) {
      await _showSubscriptionDialog();
      return;
    }

    // 새 CancelToken 생성
    _ocrCancelToken?.cancel('New request started');
    _ocrCancelToken = CancelToken();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      ReceiptData receiptData;
      
      // Gemini OCR 서버로 요청
      final ocrServerUrl = ref.read(ocrServerUrlProvider);
      final provider = ref.read(ocrProviderProvider);

      debugPrint('[OCR] Using Gemini OCR server...');

      final sllmService = ref.read(sllmServiceProvider);
      receiptData = await sllmService.parseReceiptFromBytes(
        _imageBytes!,
        ocrServerUrl: ocrServerUrl,
        provider: provider,
        cancelToken: _ocrCancelToken,
      );

      if (!mounted) return;

      setState(() {
        _receiptData = receiptData;
        _isProcessing = false;

        // Auto-fill form fields
        if (receiptData.storeName != null) {
          _descriptionController.text = receiptData.storeName!;
        }
        if (receiptData.totalAmount != null) {
          _amountController.text = receiptData.totalAmount!.toStringAsFixed(0);
        }
        if (receiptData.date != null) {
          _selectedDate = receiptData.date!;
        }
        
        // 서버에서 받은 카테고리를 앱 카테고리에 매칭
        if (receiptData.category != null && receiptData.category!.isNotEmpty) {
          _selectedCategory = Category.matchOcrCategory(
            receiptData.category!,
            isIncome: receiptData.isIncome,
          );
        } else {
          _selectedCategory = _guessCategory(receiptData.storeName ?? '');
        }
        
        // 수입 여부 자동 설정
        _isIncome = receiptData.isIncome;
      });
      
      // OCR 성공 시 사용량 증가
      await ref.read(quotaProvider.notifier).incrementUsage();
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('[OCR] Request cancelled by user');
        // 취소된 경우 에러 메시지 표시하지 않음
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.message ?? '서버 요청 실패';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _guessCategory(String storeName) {
    // 상점명으로 카테고리 추론 (Category.matchOcrCategory 활용)
    return Category.matchOcrCategory(storeName);
  }

  /// 다중 이미지 선택 (갤러리에서)
  Future<void> _pickMultipleImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        // 일괄 모드로 전환
        final items = <BatchReceiptItem>[];
        for (final file in pickedFiles) {
          final bytes = await file.readAsBytes();
          items.add(BatchReceiptItem(file: file, bytes: bytes));
        }

        setState(() {
          _batchItems = items;
          _isBatchMode = true;
          _errorMessage = null;
        });

        // 일괄 OCR 처리 시작
        await _processBatchReceipts();
      }
    } catch (e) {
      setState(() {
        _errorMessage = '이미지를 불러올 수 없습니다: $e';
      });
    }
  }

  /// 일괄 OCR 처리 (병렬)
  Future<void> _processBatchReceipts() async {
    if (_batchItems.isEmpty) return;

    setState(() {
      _isBatchProcessing = true;
    });

    // Gemini OCR 설정 읽기
    final ocrServerUrl = ref.read(ocrServerUrlProvider);
    final provider = ref.read(ocrProviderProvider);

    // 모든 아이템을 처리 중 상태로 변경
    setState(() {
      for (var item in _batchItems) {
        item.isProcessing = true;
      }
    });

    // 병렬로 모든 영수증 처리 (Gemini OCR)
    await Future.wait(
      _batchItems.asMap().entries.map((entry) async {
        final index = entry.key;
        final item = entry.value;

        if (!mounted) return;

        try {
          final sllmService = ref.read(sllmServiceProvider);
          final receiptData = await sllmService.parseReceiptFromBytes(
            item.bytes,
            ocrServerUrl: ocrServerUrl,
            provider: provider,
          );

          if (mounted) {
            setState(() {
              _batchItems[index].isProcessing = false;
              _batchItems[index].isProcessed = true;
              _batchItems[index].updateFromReceiptData(receiptData, _guessCategory);
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _batchItems[index].isProcessing = false;
              _batchItems[index].isProcessed = true;
              _batchItems[index].errorMessage = e.toString();
            });
          }
        }
      }),
    );

    if (mounted) {
      setState(() {
        _isBatchProcessing = false;
      });
    }
  }

  /// 일괄 저장
  Future<void> _saveBatchTransactions() async {
    final syncService = ref.read(syncServiceProvider);
    final repository = ref.read(transactionRepositoryProvider);

    final selectedItems = _batchItems.where((item) => 
      item.isSelected && 
      item.isProcessed && 
      item.errorMessage == null
    ).toList();

    if (selectedItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장할 영수증이 없습니다')),
        );
      }
      return;
    }

    int savedCount = 0;
    int skippedCount = 0;

    for (final item in selectedItems) {
      final amount = double.tryParse(item.amount);
      if (amount == null || amount <= 0) {
        skippedCount++;
        continue;
      }

      if (item.description.isEmpty) {
        skippedCount++;
        continue;
      }

      // 중복 체크 (일괄 처리에서는 다이얼로그 없이 스킵)
      final duplicate = await repository.findDuplicateTransaction(
        storeName: item.receiptData?.storeName,
        date: item.date,
        amount: amount,
      );

      if (duplicate != null) {
        skippedCount++;
        continue;
      }

      final transaction = TransactionModel(
        id: const Uuid().v4(),
        date: item.date,
        category: item.category,
        amount: amount,
        description: item.description,
        receiptImagePath: item.file.path,
        storeName: item.receiptData?.storeName,
        isIncome: item.isIncome,
        ownerKey: syncService.myKey,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.insertTransaction(transaction);
      
      // 예산 체크 및 알림
      final budgetAlertService = BudgetAlertService(repository);
      if (mounted) {
        budgetAlertService.setContext(context);
        await budgetAlertService.checkBudgetAndNotify(
          categoryId: item.category,
          isIncome: item.isIncome,
        );
      }
      savedCount++;
    }

    // Refresh providers
    ref.invalidate(transactionsProvider);
    ref.invalidate(selectedDateTransactionsProvider);
    ref.invalidate(monthlyTransactionsProvider);
    ref.invalidate(monthlyStatsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedCount건 저장 완료${skippedCount > 0 ? ' ($skippedCount건 스킵)' : ''}'),
          backgroundColor: AppColors.income,
        ),
      );

      // 일괄 모드 종료
      setState(() {
        _batchItems.clear();
        _isBatchMode = false;
      });
    }
  }

  /// 일괄 모드 취소
  void _cancelBatchMode() {
    setState(() {
      _batchItems.clear();
      _isBatchMode = false;
      _isBatchProcessing = false;
    });
  }

  /// 구독 유도 다이얼로그
  Future<void> _showSubscriptionDialog() async {
    final subscription = ref.read(subscriptionProvider);
    final quotaState = ref.watch(quotaProvider);
    final adNotifier = ref.read(adProvider.notifier);
    final tier = subscription.tier;
    
    final remainingQuota = quotaState.getRemainingFreeQuota();
    final bool isFreeExhausted = tier == SubscriptionTier.free && remainingQuota <= 0;
    final bool canWatchAd = adNotifier.isRewardedAdReady && isFreeExhausted;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isFreeExhausted ? Icons.lock : Icons.workspace_premium, 
              color: isFreeExhausted ? Colors.red : const Color(0xFF6366F1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(isFreeExhausted ? 'OCR 횟수 소진' : '프리미엄 구독'),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 18,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFreeExhausted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '무료 체험 5회가 모두 소진되었습니다.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (canWatchAd)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.play_circle_filled, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '광고를 시청하면 1회 추가 사용 가능!',
                          style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✨ 프리미엄 혜택', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• 무제한 OCR 스캔'),
                  Text('• 광고 제거'),
                  Text('• 클라우드 동기화'),
                  Text('• 멀티 디바이스 지원'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '💰 월 ₩1,900 / 연 ₩19,000',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: Color(0xFF6366F1),
              ),
            ),
          ],
        ),
        actions: [
          if (canWatchAd)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop('watchAd'),
              icon: const Icon(Icons.play_circle_outline, color: Colors.green),
              label: const Text('광고 보기', style: TextStyle(color: Colors.green)),
            ),
          if (!isFreeExhausted)
            TextButton(
              onPressed: () => Navigator.of(context).pop('manual'),
              child: const Text('수동 입력'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('subscribe'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text(
              '구독하기', 
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    
    if (result == 'watchAd') {
      final rewarded = await adNotifier.showRewardedAd(
        onRewarded: () async {
          await ref.read(quotaProvider.notifier).addBonusFromAd();
        },
      );
      if (rewarded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 OCR 1회가 추가되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else if (result == 'subscribe') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
      );
    }
  }

  /// 이미지 취소 확인 다이얼로그
  Future<void> _showCancelConfirmDialog() async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('이미지 취소'),
          ],
        ),
        content: const Text('영수증 이미지 올리는 것을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속 분석'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
            ),
            child: const Text('취소', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldCancel == true && mounted) {
      _ocrCancelToken?.cancel('Cancelled by user');
      _ocrCancelToken = null;
      
      setState(() {
        _pickedFile = null;
        _imageBytes = null;
        _receiptData = null;
        _errorMessage = null;
        _isProcessing = false;
        // 폼 필드도 초기화
        _descriptionController.clear();
        _amountController.clear();
        _selectedCategory = null;
        _isIncome = false;
        _selectedDate = DateTime.now();
      });
    }
  }

  Future<void> _saveTransaction() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 금액을 입력해주세요')),
      );
      return;
    }

    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설명을 입력해주세요')),
      );
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요')),
      );
      return;
    }

    final syncService = ref.read(syncServiceProvider);
    final repository = ref.read(transactionRepositoryProvider);

    // Check for duplicate transaction
    final duplicate = await repository.findDuplicateTransaction(
      storeName: _receiptData?.storeName,
      date: _selectedDate,
      amount: amount,
    );

    if (duplicate != null && mounted) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('중복 영수증 감지'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('동일한 거래가 이미 등록되어 있습니다:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📅 날짜: ${Formatters.dateKorean(duplicate.date)}'),
                    Text('💰 금액: ${Formatters.currency(duplicate.amount)}'),
                    if (duplicate.storeName != null)
                      Text('🏪 상점: ${duplicate.storeName}'),
                    Text('📝 설명: ${duplicate.description}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('그래도 저장하시겠습니까?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text('저장', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (shouldContinue != true) {
        return;
      }
    }

    final transaction = TransactionModel(
      id: const Uuid().v4(),
      date: _selectedDate,
      category: _selectedCategory ?? '기타',
      amount: amount,
      description: _descriptionController.text,
      receiptImagePath: _pickedFile?.path,
      storeName: _receiptData?.storeName,
      isIncome: _isIncome,
      ownerKey: syncService.myKey,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repository.insertTransaction(transaction);
    
    // 예산 체크 및 알림
    final budgetAlertService = BudgetAlertService(repository);
    if (mounted) {
      budgetAlertService.setContext(context);
      await budgetAlertService.checkBudgetAndNotify(
        categoryId: _selectedCategory ?? '기타',
        isIncome: _isIncome,
      );
    }

    // Refresh providers
    ref.invalidate(transactionsProvider);
    ref.invalidate(selectedDateTransactionsProvider);
    ref.invalidate(monthlyTransactionsProvider);
    ref.invalidate(monthlyStatsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('거래가 저장되었습니다'),
          backgroundColor: AppColors.income,
        ),
      );

      // Reset form
      setState(() {
        _pickedFile = null;
        _imageBytes = null;
        _receiptData = null;
        _descriptionController.clear();
        _amountController.clear();
        _selectedCategory = null;
        _isIncome = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // 일괄 처리 모드일 때는 별도 UI 표시
    if (_isBatchMode) {
      return BatchModeView(
        items: _batchItems,
        isProcessing: _isBatchProcessing,
        onCancel: _cancelBatchMode,
        onSave: _saveBatchTransactions,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('영수증 등록'),
        actions: [
          if (_pickedFile != null || _descriptionController.text.isNotEmpty)
            TextButton(
              onPressed: _saveTransaction,
              child: const Text(
                '저장',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Capture Section
            if (_imageBytes == null)
              _buildImagePickerButtons()
            else
              _buildImagePreview(),

            const SizedBox(height: 24),

            // Processing Indicator
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('영수증을 분석하고 있습니다...'),
                  ],
                ),
              ),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.expense.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.expense),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.expense),
                      ),
                    ),
                  ],
                ),
              ),

            // OCR 디버그 정보 표시
            if (_showDebugInfo && _receiptData != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bug_report, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'OCR 분석 결과 (디버그)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _showDebugInfo = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDebugRow('🏪 상점명', _receiptData!.storeName ?? '(인식 안됨)'),
                    _buildDebugRow('📅 날짜', _receiptData!.date?.toString().split(' ')[0] ?? '(인식 안됨)'),
                    _buildDebugRow('💰 총액', _receiptData!.totalAmount != null 
                        ? '₩${_receiptData!.totalAmount!.toStringAsFixed(0)}' 
                        : '(인식 안됨)'),
                    _buildDebugRow('🏷️ 카테고리', _receiptData!.category ?? '(자동 추론)'),
                    _buildDebugRow('📦 품목 수', '${_receiptData!.items.length}개'),
                    if (_receiptData!.items.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('품목 목록:', style: TextStyle(fontWeight: FontWeight.w500)),
                      ...(_receiptData!.items.take(5).map((item) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text('• ${item.name}: ₩${item.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12)),
                      ))),
                      if (_receiptData!.items.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Text('... 외 ${_receiptData!.items.length - 5}개',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                    ],
                  ],
                ),
              ),

            // Form Fields using Extracted Widget
            if (!_isProcessing) ...[
              const SizedBox(height: 16),
              ReceiptForm(
                amountController: _amountController,
                descriptionController: _descriptionController,
                isIncome: _isIncome,
                selectedDate: _selectedDate,
                selectedCategory: _selectedCategory,
                onIncomeChanged: (val) => setState(() => _isIncome = val),
                onDateChanged: (val) => setState(() => _selectedDate = val),
                onCategoryChanged: (val) => setState(() => _selectedCategory = val),
                onSave: _saveTransaction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildImagePickerButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildPickerButton(
                icon: Icons.camera_alt,
                label: '카메라',
                onTap: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPickerButton(
                icon: Icons.photo_library,
                label: '갤러리',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 여러 장 선택 버튼
        InkWell(
          onTap: _pickMultipleImages,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 32, color: AppColors.primary),
                SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '여러 장 선택',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '갤러리에서 여러 영수증을 한번에 등록',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: () => _showFullScreenImage(),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _imageBytes!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // 탭하여 확대 안내
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_in, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '탭하여 확대',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => _showCancelConfirmDialog(),
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 전체화면 이미지 뷰어
  void _showFullScreenImage() {
    if (_imageBytes == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('영수증 미리보기', style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
