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
import '../settings/local_model_manager.dart';

/// 일괄 처리용 영수증 아이템
class BatchReceiptItem {
  final XFile file;
  final Uint8List bytes;
  bool isProcessing;
  bool isProcessed;
  ReceiptData? receiptData;
  String? errorMessage;
  
  // 폼 데이터 (수정 가능)
  String description;
  String amount;
  DateTime date;
  String category;
  bool isIncome;
  bool isSelected; // 저장 대상 여부

  BatchReceiptItem({
    required this.file,
    required this.bytes,
    this.isProcessing = false,
    this.isProcessed = false,
    this.receiptData,
    this.errorMessage,
    this.description = '',
    this.amount = '',
    DateTime? date,
    this.category = '기타',
    this.isIncome = false,
    this.isSelected = true,
  }) : date = date ?? DateTime.now();

  /// OCR 결과로 폼 데이터 업데이트
  void updateFromReceiptData(ReceiptData data, String Function(String) guessCategory) {
    receiptData = data;
    if (data.storeName != null) {
      description = data.storeName!;
    }
    if (data.totalAmount != null) {
      amount = data.totalAmount!.toStringAsFixed(0);
    }
    if (data.date != null) {
      date = data.date!;
    }
    if (data.category != null && data.category!.isNotEmpty) {
      category = data.category!;
    } else {
      category = guessCategory(data.storeName ?? '');
    }
    // 수입 여부 자동 설정
    isIncome = data.isIncome;
  }
}

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
  String _selectedCategory = '기타';
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

    // 새 CancelToken 생성
    _ocrCancelToken?.cancel('New request started');
    _ocrCancelToken = CancelToken();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      ReceiptData receiptData;
      
      // OCR 모드 및 설정 읽기
      final ocrMode = ref.read(ocrModeProvider);
      final modelState = ref.read(localModelManagerProvider);
      final externalLlamaUrl = ref.read(externalLlamaUrlProvider);
      final ocrServerUrl = ref.read(ocrServerUrlProvider);

      // 모드 결정
      String effectiveMode;
      switch (ocrMode) {
        case OcrMode.local:
          if (modelState.isModelLoaded) {
            effectiveMode = 'local';
          } else {
            throw Exception('로컬 모델이 로드되지 않았습니다. 설정에서 모델을 먼저 로드해주세요.');
          }
          break;
        case OcrMode.externalLlama:
          effectiveMode = 'externalLlama';
          break;
        case OcrMode.server:
          effectiveMode = 'server';
          break;
        case OcrMode.auto:
        default:
          // 자동: 로컬 > 외부 llama > OCR 서버
          if (modelState.isModelLoaded) {
            effectiveMode = 'local';
          } else {
            effectiveMode = 'auto'; // 외부 시도 후 서버로 폴백
          }
          break;
      }

      debugPrint('[OCR] Mode: $ocrMode, Effective: $effectiveMode');

      if (effectiveMode == 'local') {
        // 로컬 OCR 사용
        debugPrint('[OCR] Using local OCR...');
        final localOcrService = ref.read(localModelManagerProvider.notifier).localOcrService;
        receiptData = await localOcrService.parseReceiptFromBytes(_imageBytes!);
      } else {
        // 서버 OCR 사용 (externalLlama, server, auto)
        debugPrint('[OCR] Using server OCR ($effectiveMode)...');
        final sllmService = ref.read(sllmServiceProvider);
        receiptData = await sllmService.parseReceiptFromBytes(
          _imageBytes!,
          mode: effectiveMode,
          externalLlamaUrl: externalLlamaUrl,
          ocrServerUrl: ocrServerUrl,
          provider: ref.read(ocrProviderProvider),
          cancelToken: _ocrCancelToken,
        );
      }

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
        
        // 서버에서 받은 카테고리가 있으면 사용, 없으면 상점명으로 추론
        if (receiptData.category != null && receiptData.category!.isNotEmpty) {
          _selectedCategory = receiptData.category!;
        } else {
          _selectedCategory = _guessCategory(receiptData.storeName ?? '');
        }
        
        // 수입 여부 자동 설정
        _isIncome = receiptData.isIncome;
      });
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
    final lower = storeName.toLowerCase();
    if (lower.contains('카페') || lower.contains('스타벅스') || lower.contains('커피')) {
      return '카페';
    } else if (lower.contains('편의점') || lower.contains('cu') || lower.contains('gs25') || lower.contains('세븐')) {
      return '편의점';
    } else if (lower.contains('마트') || lower.contains('이마트') || lower.contains('홈플러스')) {
      return '마트';
    } else if (lower.contains('약국') || lower.contains('병원') || lower.contains('의원')) {
      return '의료';
    } else if (lower.contains('주유') || lower.contains('택시') || lower.contains('버스')) {
      return '교통';
    }
    return '기타';
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

    // OCR 설정 읽기
    final ocrMode = ref.read(ocrModeProvider);
    final modelState = ref.read(localModelManagerProvider);
    final externalLlamaUrl = ref.read(externalLlamaUrlProvider);
    final ocrServerUrl = ref.read(ocrServerUrlProvider);

    // 모드 결정
    String effectiveMode;
    switch (ocrMode) {
      case OcrMode.local:
        if (modelState.isModelLoaded) {
          effectiveMode = 'local';
        } else {
          setState(() {
            _isBatchProcessing = false;
            _errorMessage = '로컬 모델이 로드되지 않았습니다.';
          });
          return;
        }
        break;
      case OcrMode.externalLlama:
        effectiveMode = 'externalLlama';
        break;
      case OcrMode.server:
        effectiveMode = 'server';
        break;
      case OcrMode.auto:
      default:
        if (modelState.isModelLoaded) {
          effectiveMode = 'local';
        } else {
          effectiveMode = 'auto';
        }
        break;
    }

    // 모든 아이템을 처리 중 상태로 변경
    setState(() {
      for (var item in _batchItems) {
        item.isProcessing = true;
      }
    });

    // 병렬로 모든 영수증 처리
    await Future.wait(
      _batchItems.asMap().entries.map((entry) async {
        final index = entry.key;
        final item = entry.value;

        if (!mounted) return;

        try {
          ReceiptData receiptData;

          if (effectiveMode == 'local') {
            final localOcrService = ref.read(localModelManagerProvider.notifier).localOcrService;
            receiptData = await localOcrService.parseReceiptFromBytes(item.bytes);
          } else {
            final sllmService = ref.read(sllmServiceProvider);
            receiptData = await sllmService.parseReceiptFromBytes(
              item.bytes,
              mode: effectiveMode,
              externalLlamaUrl: externalLlamaUrl,
              ocrServerUrl: ocrServerUrl,
            );
          }

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
      // 진행 중인 OCR 요청 취소
      _ocrCancelToken?.cancel('Cancelled by user');
      _ocrCancelToken = null;
      
      setState(() {
        _pickedFile = null;
        _imageBytes = null;
        _receiptData = null;
        _errorMessage = null;
        _isProcessing = false;
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

    final syncService = ref.read(syncServiceProvider);
    final repository = ref.read(transactionRepositoryProvider);

    // Check for duplicate transaction
    final duplicate = await repository.findDuplicateTransaction(
      storeName: _receiptData?.storeName,
      date: _selectedDate,
      amount: amount,
    );

    if (duplicate != null && mounted) {
      // Show confirmation dialog
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
                  color: Colors.grey.withAlpha(30),
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
      category: _selectedCategory,
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
        _selectedCategory = '기타';
        _isIncome = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // 일괄 처리 모드일 때는 별도 UI 표시
    if (_isBatchMode) {
      return _buildBatchModeUI();
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
        padding: const EdgeInsets.all(20),
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
                  color: AppColors.expense.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.expense.withAlpha(75)),
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
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withAlpha(75)),
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
                    const SizedBox(height: 8),
                    ExpansionTile(
                      title: const Text('원본 텍스트 보기', style: TextStyle(fontSize: 12)),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 8),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _receiptData!.rawText ?? '(없음)',
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Form Fields
            if (!_isProcessing) ...[
              const SizedBox(height: 16),
              _buildFormFields(),
            ],
          ],
        ),
      ),
    );
  }

  /// 일괄 처리 모드 UI
  Widget _buildBatchModeUI() {
    final processedCount = _batchItems.where((item) => item.isProcessed).length;
    final totalCount = _batchItems.length;
    final selectedCount = _batchItems.where((item) => item.isSelected && item.isProcessed && item.errorMessage == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('일괄 등록 ($totalCount장)'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cancelBatchMode,
        ),
        actions: [
          if (!_isBatchProcessing && processedCount > 0)
            TextButton.icon(
              onPressed: selectedCount > 0 ? _saveBatchTransactions : null,
              icon: const Icon(Icons.save, size: 18),
              label: Text('저장 ($selectedCount건)'),
              style: TextButton.styleFrom(
                foregroundColor: selectedCount > 0 ? AppColors.primary : Colors.grey,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 진행 상태 표시
          if (_isBatchProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withAlpha(25),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('분석 중... ($processedCount / $totalCount)'),
                  const Spacer(),
                  LinearProgressIndicator(
                    value: totalCount > 0 ? processedCount / totalCount : 0,
                    backgroundColor: Colors.grey.withAlpha(50),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ],
              ),
            )
          else if (processedCount == totalCount)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.income.withAlpha(25),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.income, size: 20),
                  const SizedBox(width: 8),
                  Text('$totalCount장 분석 완료! 저장할 항목을 선택하세요.'),
                ],
              ),
            ),

          // 일괄 선택/해제 버튼
          if (!_isBatchProcessing && processedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        for (var item in _batchItems) {
                          if (item.isProcessed && item.errorMessage == null) {
                            item.isSelected = true;
                          }
                        }
                      });
                    },
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('전체 선택'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        for (var item in _batchItems) {
                          item.isSelected = false;
                        }
                      });
                    },
                    icon: const Icon(Icons.deselect, size: 18),
                    label: const Text('전체 해제'),
                  ),
                ],
              ),
            ),

          // 영수증 리스트
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _batchItems.length,
              itemBuilder: (context, index) => _buildBatchItemCard(index),
            ),
          ),
        ],
      ),
    );
  }

  /// 개별 일괄 처리 아이템 카드
  Widget _buildBatchItemCard(int index) {
    final item = _batchItems[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isSelected && item.errorMessage == null
              ? AppColors.primary.withAlpha(100)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // 헤더 (이미지 썸네일 + 상태)
          InkWell(
            onTap: item.isProcessed && item.errorMessage == null
                ? () => setState(() => item.isSelected = !item.isSelected)
                : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 썸네일 이미지
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      item.bytes,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 상태 및 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '영수증 ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (item.isProcessing)
                          const Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('분석 중...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          )
                        else if (item.errorMessage != null)
                          Row(
                            children: [
                              const Icon(Icons.error, color: AppColors.expense, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  item.errorMessage!,
                                  style: const TextStyle(color: AppColors.expense, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else if (item.isProcessed)
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.income, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                item.description.isNotEmpty ? item.description : '(상점명 없음)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₩${item.amount.isNotEmpty ? item.amount : "0"}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          )
                        else
                          const Text('대기 중...', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),

                  // 체크박스 (처리 완료 시)
                  if (item.isProcessed && item.errorMessage == null)
                    Checkbox(
                      value: item.isSelected,
                      onChanged: (value) => setState(() => item.isSelected = value ?? false),
                      activeColor: AppColors.primary,
                    ),
                ],
              ),
            ),
          ),

          // 편집 가능한 폼 (선택된 항목만)
          if (item.isProcessed && item.errorMessage == null && item.isSelected)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  // 설명 (상점명)
                  TextField(
                    controller: TextEditingController(text: item.description)..selection = TextSelection.collapsed(offset: item.description.length),
                    onChanged: (value) => item.description = value,
                    decoration: InputDecoration(
                      labelText: '설명',
                      isDense: true,
                      filled: true,
                      fillColor: Theme.of(context).cardTheme.color,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 금액
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(text: item.amount)..selection = TextSelection.collapsed(offset: item.amount.length),
                          onChanged: (value) => item.amount = value,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '금액',
                            prefixText: '₩ ',
                            isDense: true,
                            filled: true,
                            fillColor: Theme.of(context).cardTheme.color,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 카테고리 드롭다운
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: Category.defaultCategories.any((c) => c.name == item.category)
                              ? item.category
                              : '기타',
                          decoration: InputDecoration(
                            labelText: '카테고리',
                            isDense: true,
                            filled: true,
                            fillColor: Theme.of(context).cardTheme.color,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: Category.defaultCategories
                              .where((c) => c.name != '수입')
                              .map((c) => DropdownMenuItem(
                                    value: c.name,
                                    child: Text('${c.emoji} ${c.name}', style: const TextStyle(fontSize: 12)),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => item.category = value ?? '기타'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 날짜 선택
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: item.date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (date != null) {
                        setState(() => item.date = date);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            Formatters.dateKorean(item.date),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withAlpha(100),
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
            color: AppColors.primary.withAlpha(75),
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
                color: Colors.black.withOpacity(0.6),
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

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Income/Expense Toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  label: '지출',
                  isSelected: !_isIncome,
                  onTap: () => setState(() => _isIncome = false),
                  color: AppColors.expense,
                ),
              ),
              Expanded(
                child: _buildToggleButton(
                  label: '수입',
                  isSelected: _isIncome,
                  onTap: () => setState(() => _isIncome = true),
                  color: AppColors.income,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Amount
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: '금액',
            prefixText: '₩ ',
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: '설명',
            hintText: '거래 내용을 입력하세요',
            filled: true,
            fillColor: Theme.of(context).cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Category
        _buildCategorySelector(),
        const SizedBox(height: 16),

        // Date
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (date != null) {
              setState(() => _selectedDate = date);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  Formatters.dateKorean(_selectedDate),
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Save Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _saveTransaction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              '저장하기',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    final categories = Category.defaultCategories
        .where((c) => c.name != '수입')
        .toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((category) {
        final isSelected = _selectedCategory == category.name;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = category.name),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? category.color.withAlpha(50)
                  : Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? category.color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  category.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
