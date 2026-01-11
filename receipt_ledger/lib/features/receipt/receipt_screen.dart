import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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

class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  XFile? _pickedFile;
  Uint8List? _imageBytes;
  bool _isProcessing = false;
  ReceiptData? _receiptData;
  String? _errorMessage;
  bool _showDebugInfo = true; // 디버그 모드 ON/OFF

  // Form controllers
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = '기타';
  bool _isIncome = false;

  @override
  void dispose() {
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

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final sllmService = ref.read(sllmServiceProvider);
      final receiptData = await sllmService.parseReceiptFromBytes(_imageBytes!);

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
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
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

  Widget _buildImagePickerButtons() {
    return Row(
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
    return Stack(
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
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: () {
              setState(() {
                _pickedFile = null;
                _imageBytes = null;
                _receiptData = null;
              });
            },
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
