import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/category_provider.dart';
import '../models/category.dart';

class CategorySettingsScreen extends StatefulWidget {
  const CategorySettingsScreen({super.key});

  @override
  State<CategorySettingsScreen> createState() => _CategorySettingsScreenState();
}

class _CategorySettingsScreenState extends State<CategorySettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });
  }

  void _showCategorySheet({CategoryModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CategoryFormSheet(existing: existing),
    );
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    if (category.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기본 카테고리는 삭제할 수 없습니다')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text(
          '"${category.name}" 카테고리를 삭제하시겠습니까?\n'
          '이 카테고리의 모든 일정과 할 일은 기본 카테고리로 이동됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final success = await context.read<CategoryProvider>().deleteCategory(category.id);
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catProvider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('카테고리 관리'),
      ),
      body: catProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : catProvider.categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('카테고리가 없습니다', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: catProvider.categories.length,
                  itemBuilder: (context, index) {
                    final cat = catProvider.categories[index];
                    return Dismissible(
                      key: Key(cat.id),
                      direction: cat.isDefault
                          ? DismissDirection.none
                          : DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _deleteCategory(cat);
                        return false; // We handle deletion ourselves
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cat.colorValue.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: cat.emoji != null && cat.emoji!.isNotEmpty
                                ? Text(cat.emoji!, style: const TextStyle(fontSize: 18))
                                : Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: cat.colorValue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(cat.name),
                        subtitle: cat.isDefault ? const Text('기본 카테고리') : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: cat.colorValue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.withAlpha(60),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                        onTap: () => _showCategorySheet(existing: cat),
                        onLongPress: cat.isDefault ? null : () => _deleteCategory(cat),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategorySheet(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final CategoryModel? existing;

  const _CategoryFormSheet({this.existing});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController();
  final _hexController = TextEditingController();
  late String _selectedColor;
  bool _isLoading = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _emojiController.text = widget.existing!.emoji ?? '';
      _selectedColor = widget.existing!.color;
    } else {
      _selectedColor = CategoryModel.presetColors[5]; // Blue default
    }
    _hexController.text = _selectedColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emojiController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    final catProvider = context.read<CategoryProvider>();
    bool success;

    if (isEditing) {
      success = await catProvider.updateCategory(
        widget.existing!.id,
        name: name,
        color: _selectedColor,
        emoji: _emojiController.text.trim(),
      );
    } else {
      success = await catProvider.createCategory(
        name: name,
        color: _selectedColor,
        emoji: _emojiController.text.trim().isEmpty
            ? null
            : _emojiController.text.trim(),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다')),
        );
      }
    }
  }

  Color _parseHex(String hex) {
    try {
      final cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEditing ? '카테고리 수정' : '새 카테고리',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '이름',
              border: OutlineInputBorder(),
              hintText: '카테고리 이름',
            ),
            autofocus: !isEditing,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emojiController,
            decoration: const InputDecoration(
              labelText: '이모지 (선택)',
              border: OutlineInputBorder(),
              hintText: '예: \u{1F4BC} \u{1F3E0} \u{1F3CB}',
            ),
          ),
          const SizedBox(height: 16),
          Text('색상', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: CategoryModel.presetColors.map((hex) {
              final isSelected = _selectedColor == hex;
              final color = _parseHex(hex);
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedColor = hex;
                  _hexController.text = hex;
                }),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                        : Border.all(color: Colors.grey.withAlpha(60)),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hexController,
                  decoration: const InputDecoration(
                    labelText: 'HEX 코드',
                    border: OutlineInputBorder(),
                    hintText: '#FF5722',
                    prefixIcon: Icon(Icons.color_lens, size: 20),
                  ),
                  onChanged: (val) {
                    if (RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(val)) {
                      setState(() => _selectedColor = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _parseHex(_selectedColor),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withAlpha(60)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isLoading ? null : _save,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? '수정' : '추가'),
            ),
          ),
        ],
      ),
    );
  }
}
