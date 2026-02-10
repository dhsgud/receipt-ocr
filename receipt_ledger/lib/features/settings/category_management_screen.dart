import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category.dart';

/// 카테고리 관리 화면
/// 사용자 정의 카테고리 추가, 수정, 삭제 기능 제공
class CategoryManagementView extends ConsumerStatefulWidget {
  const CategoryManagementView({super.key});

  @override
  ConsumerState<CategoryManagementView> createState() =>
      _CategoryManagementViewState();
}

class _CategoryManagementViewState
    extends ConsumerState<CategoryManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '지출 카테고리'),
              Tab(text: '수입 카테고리'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildExpenseCategoryList(),
              _buildIncomeCategoryList(),
            ],
          ),
        ),
      ],
    );
  }

  /// 지출 카테고리 리스트 (대분류 → 소분류 계층 구조)
  Widget _buildExpenseCategoryList() {
    final parentCategories = Category.expenseParentCategories;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: parentCategories.length,
      itemBuilder: (context, index) {
        final parent = parentCategories[index];
        final subcategories = Category.getSubcategories(parent.id);

        return _buildCategoryExpansionTile(parent, subcategories);
      },
    );
  }

  /// 대분류 카테고리와 소분류 확장 타일
  Widget _buildCategoryExpansionTile(
      Category parent, List<Category> subcategories) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: parent.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              parent.emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          parent.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${subcategories.length}개 소분류',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 소분류 추가 버튼
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _showAddSubcategoryDialog(parent),
              tooltip: '소분류 추가',
            ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (subcategories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '소분류가 없습니다. + 버튼을 눌러 추가하세요.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...subcategories.map((sub) => _buildSubcategoryItem(sub)),
        ],
      ),
    );
  }

  /// 소분류 카테고리 아이템
  Widget _buildSubcategoryItem(Category subcategory) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 72, right: 16),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: subcategory.color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            subcategory.emoji,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
      title: Text(subcategory.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 수정 버튼
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => _showEditCategoryDialog(subcategory),
            tooltip: '수정',
          ),
          // 삭제 버튼 (기본 카테고리가 아닌 경우만)
          if (!subcategory.isDefault)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => _showDeleteConfirmDialog(subcategory),
              tooltip: '삭제',
            ),
        ],
      ),
    );
  }

  /// 수입 카테고리 리스트
  Widget _buildIncomeCategoryList() {
    final incomeCategories = Category.incomeCategories;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: incomeCategories.length + 1, // +1 for add button
      itemBuilder: (context, index) {
        if (index == incomeCategories.length) {
          return _buildAddCategoryButton(TransactionType.income);
        }

        final category = incomeCategories[index];
        return _buildIncomeCategoryItem(category);
      },
    );
  }

  /// 수입 카테고리 아이템
  Widget _buildIncomeCategoryItem(Category category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              category.emoji,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEditCategoryDialog(category),
              tooltip: '수정',
            ),
            if (!category.isDefault)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: () => _showDeleteConfirmDialog(category),
                tooltip: '삭제',
              ),
          ],
        ),
      ),
    );
  }

  /// 카테고리 추가 버튼
  Widget _buildAddCategoryButton(TransactionType type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add, color: Colors.grey),
        ),
        title: Text(
          type == TransactionType.expense ? '새 지출 카테고리 추가' : '새 수입 카테고리 추가',
          style: TextStyle(color: Colors.grey[600]),
        ),
        onTap: () => _showAddCategoryDialog(type),
      ),
    );
  }

  // ============================================================
  // Dialogs
  // ============================================================

  /// 소분류 카테고리 추가 다이얼로그
  void _showAddSubcategoryDialog(Category parent) {
    final nameController = TextEditingController();
    String selectedEmoji = '📌';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${parent.name} 소분류 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '카테고리 이름',
                  hintText: '예: 아침식사',
                ),
              ),
              const SizedBox(height: 16),
              _buildEmojiPicker(
                selectedEmoji: selectedEmoji,
                onChanged: (emoji) {
                  selectedEmoji = emoji;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _addSubcategory(parent, nameController.text, selectedEmoji);
                Navigator.pop(context);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  /// 카테고리 추가 다이얼로그
  void _showAddCategoryDialog(TransactionType type) {
    final nameController = TextEditingController();
    String selectedEmoji = type == TransactionType.income ? '💵' : '📦';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == TransactionType.expense ? '지출 카테고리 추가' : '수입 카테고리 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '카테고리 이름',
                  hintText: '예: 급여',
                ),
              ),
              const SizedBox(height: 16),
              _buildEmojiPicker(
                selectedEmoji: selectedEmoji,
                onChanged: (emoji) {
                  selectedEmoji = emoji;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _addCategory(type, nameController.text, selectedEmoji);
                Navigator.pop(context);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  /// 카테고리 수정 다이얼로그
  void _showEditCategoryDialog(Category category) {
    final nameController = TextEditingController(text: category.name);
    String selectedEmoji = category.emoji;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('카테고리 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '카테고리 이름',
                  ),
                ),
                const SizedBox(height: 16),
                _buildEmojiPicker(
                  selectedEmoji: selectedEmoji,
                  onChanged: (emoji) {
                    setDialogState(() {
                      selectedEmoji = emoji;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  _updateCategory(category, nameController.text, selectedEmoji);
                  Navigator.pop(context);
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  /// 카테고리 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text('\'${category.name}\' 카테고리를 삭제하시겠습니까?\n\n이 카테고리를 사용한 거래는 \'기타\'로 변경됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _deleteCategory(category);
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 이모지 선택기
  Widget _buildEmojiPicker({
    required String selectedEmoji,
    required ValueChanged<String> onChanged,
  }) {
    final commonEmojis = [
      '🍽️', '🍴', '🛵', '🥬', '☕', '🍫', '🍺',
      '🚗', '🚇', '🚕', '⛽', '🔧', '🅿️', '🛣️', '🚄', '🚌', '✈️',
      '🏠', '🏦', '🏢', '⚡', '🔥', '💧', '📡',
      '📱', '📶', '👕', '👟', '👜', '💄', '💇', '💅',
      '🧴', '🛋️', '🔌', '🐶',
      '🏥', '💊', '💪', '🏋️', '🔬',
      '🎬', '🎭', '📚', '🎮', '🎨', '🏨', '⚽',
      '📺', '🎵', '☁️', '📲', '🎫',
      '🎓', '✏️', '📖', '📜',
      '💒', '🖤', '🎁', '❤️',
      '🛡️', '📋', '💳', '🏧',
      '📦', '💵', '💰', '📈', '💼', '👴', '💸', '💝', '🎊', '📥',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '아이콘 선택',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: commonEmojis.length,
            itemBuilder: (context, index) {
              final emoji = commonEmojis[index];
              final isSelected = emoji == selectedEmoji;

              return GestureDetector(
                onTap: () => onChanged(emoji),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    border: isSelected
                        ? Border.all(color: Theme.of(context).primaryColor)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // Category Operations (TODO: 데이터베이스 연동)
  // ============================================================

  void _addSubcategory(Category parent, String name, String emoji) {
    // TODO: 데이터베이스에 새 소분류 카테고리 저장
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$emoji $name 카테고리가 추가되었습니다.')),
    );
    setState(() {});
  }

  void _addCategory(TransactionType type, String name, String emoji) {
    // TODO: 데이터베이스에 새 카테고리 저장
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$emoji $name 카테고리가 추가되었습니다.')),
    );
    setState(() {});
  }

  void _updateCategory(Category category, String name, String emoji) {
    // TODO: 데이터베이스에서 카테고리 업데이트
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$emoji $name 카테고리가 수정되었습니다.')),
    );
    setState(() {});
  }

  void _deleteCategory(Category category) {
    // TODO: 데이터베이스에서 카테고리 삭제
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${category.emoji} ${category.name} 카테고리가 삭제되었습니다.')),
    );
    setState(() {});
  }
}
