import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/category.dart';
import '../models/batch_receipt_item.dart';

class BatchModeView extends StatefulWidget {
  final List<BatchReceiptItem> items;
  final bool isProcessing;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const BatchModeView({
    super.key,
    required this.items,
    required this.isProcessing,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<BatchModeView> createState() => _BatchModeViewState();
}

class _BatchModeViewState extends State<BatchModeView> {
  @override
  Widget build(BuildContext context) {
    final processedCount = widget.items.where((item) => item.isProcessed).length;
    final totalCount = widget.items.length;
    final selectedCount = widget.items.where((item) => item.isSelected && item.isProcessed && item.errorMessage == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('일괄 등록 ($totalCount장)'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
        actions: [
          if (!widget.isProcessing && processedCount > 0)
            TextButton.icon(
              onPressed: selectedCount > 0 ? widget.onSave : null,
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
          if (widget.isProcessing)
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withValues(alpha: 0.1),
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
                  Expanded(
                    flex: 0,
                    child: SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: totalCount > 0 ? processedCount / totalCount : 0,
                        backgroundColor: Colors.grey.withValues(alpha: 0.2),
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (processedCount == totalCount)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.income.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.income, size: 20),
                  const SizedBox(width: 8),
                  Text('$totalCount장 분석 완료! 저장할 항목을 선택하세요.'),
                ],
              ),
            ),

          // 일괄 선택/해제 버튼
          if (!widget.isProcessing && processedCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        for (var item in widget.items) {
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
                        for (var item in widget.items) {
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
              itemCount: widget.items.length,
              itemBuilder: (context, index) => _buildBatchItemCard(index),
            ),
          ),
        ],
      ),
    );
  }

  /// 개별 일괄 처리 아이템 카드
  Widget _buildBatchItemCard(int index) {
    final item = widget.items[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.isSelected && item.errorMessage == null
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 2,
        ),
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.05),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
}
