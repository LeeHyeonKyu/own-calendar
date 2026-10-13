import 'package:flutter/material.dart';
import '../models/task.dart';
import '../themes/spacing.dart';

/// Maximum nesting depth for checklist items (root = level 1).
const _maxDepth = 3;

/// Editor widget for a 3-level nested checklist.
/// Supports add, delete, edit text, toggle checked, and add child items.
class ChecklistEditor extends StatefulWidget {
  final List<ChecklistItem> items;
  final ValueChanged<List<ChecklistItem>> onChanged;

  const ChecklistEditor({
    super.key,
    required this.items,
    required this.onChanged,
  });

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  final _newItemController = TextEditingController();
  final _newItemFocus = FocusNode();

  @override
  void dispose() {
    _newItemController.dispose();
    _newItemFocus.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged(List.from(widget.items));

  void _addItem() {
    final text = _newItemController.text.trim();
    if (text.isEmpty) return;
    widget.items.add(ChecklistItem(text: text));
    _newItemController.clear();
    _newItemFocus.requestFocus();
    _notify();
  }

  void _removeItem(List<ChecklistItem> parent, int index) {
    parent.removeAt(index);
    _notify();
  }

  void _addChild(ChecklistItem parent) {
    parent.children.add(ChecklistItem(text: ''));
    _notify();
  }

  void _toggleChecked(ChecklistItem item) {
    item.checked = !item.checked;
    _notify();
  }

  void _updateText(ChecklistItem item, String text) {
    item.text = text;
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.items.asMap().entries.map((entry) => _buildItemTree(
              widget.items,
              entry.key,
              entry.value,
              depth: 1,
            )),
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newItemController,
                focusNode: _newItemFocus,
                decoration: const InputDecoration(
                  hintText: '새 항목 추가',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.sm,
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _addItem(),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            IconButton.filled(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemTree(
    List<ChecklistItem> parentList,
    int index,
    ChecklistItem item, {
    required int depth,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: (depth - 1) * 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChecklistItemRow(
            item: item,
            depth: depth,
            onToggle: () => _toggleChecked(item),
            onTextChanged: (text) => _updateText(item, text),
            onDelete: () => _removeItem(parentList, index),
            onAddChild: depth < _maxDepth ? () => _addChild(item) : null,
          ),
          ...item.children.asMap().entries.map((entry) => _buildItemTree(
                item.children,
                entry.key,
                entry.value,
                depth: depth + 1,
              )),
        ],
      ),
    );
  }
}

class _ChecklistItemRow extends StatefulWidget {
  final ChecklistItem item;
  final int depth;
  final VoidCallback onToggle;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onDelete;
  final VoidCallback? onAddChild;

  const _ChecklistItemRow({
    required this.item,
    required this.depth,
    required this.onToggle,
    required this.onTextChanged,
    required this.onDelete,
    this.onAddChild,
  });

  @override
  State<_ChecklistItemRow> createState() => _ChecklistItemRowState();
}

class _ChecklistItemRowState extends State<_ChecklistItemRow> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item.text);
  }

  @override
  void didUpdateWidget(covariant _ChecklistItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id) {
      _controller.text = widget.item.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final checkSize = widget.depth == 1 ? 20.0 : 16.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              width: checkSize,
              height: checkSize,
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.item.checked
                      ? AppColors.taskDone
                      : cs.outline,
                  width: widget.depth == 1 ? 2 : 1.5,
                ),
                borderRadius: BorderRadius.circular(3),
                color: widget.item.checked ? AppColors.taskDone : null,
              ),
              child: widget.item.checked
                  ? Icon(Icons.check,
                      size: checkSize - 6, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(
                fontSize: widget.depth == 1
                    ? AppTypography.body
                    : AppTypography.bodySmall,
                decoration:
                    widget.item.checked ? TextDecoration.lineThrough : null,
                color: widget.item.checked ? cs.outline : null,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: widget.onTextChanged,
            ),
          ),
          if (widget.onAddChild != null)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                icon: const Icon(Icons.subdirectory_arrow_right, size: 16),
                onPressed: widget.onAddChild,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: '하위 항목 추가',
              ),
            ),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              icon: Icon(Icons.close, size: 16, color: cs.error),
              onPressed: widget.onDelete,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: '삭제',
            ),
          ),
        ],
      ),
    );
  }
}
