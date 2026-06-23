import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../app/theme.dart';
import '../../../data/models/entities.dart';
import '../../../data/repositories/category_repository.dart';

enum CategoryTreeMode { select, manage }

/// 可展开/收缩的多级分类树
class CategoryExpandableTree extends StatefulWidget {
  const CategoryExpandableTree({
    super.key,
    required this.catRepo,
    required this.roots,
    this.mode = CategoryTreeMode.select,
    this.selectedCategoryId,
    this.onCategorySelected,
    this.onEditCategory,
    this.onDeleteCategory,
    this.onAddSubCategory,
    this.initialExpandedIds = const {},
    this.maxHeight,
  });

  final CategoryRepository catRepo;
  final List<CategoryEntity> roots;
  final CategoryTreeMode mode;
  final int? selectedCategoryId;
  final ValueChanged<CategoryEntity>? onCategorySelected;
  final Future<void> Function(CategoryEntity cat)? onEditCategory;
  final Future<void> Function(CategoryEntity cat)? onDeleteCategory;
  final Future<void> Function(CategoryEntity parent)? onAddSubCategory;
  final Set<int> initialExpandedIds;
  final double? maxHeight;

  @override
  State<CategoryExpandableTree> createState() => CategoryExpandableTreeState();
}

class CategoryExpandableTreeState extends State<CategoryExpandableTree> {
  late Set<int> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = Set.from(widget.initialExpandedIds);
  }

  void expandToCategory(int categoryId) {
    final cat = widget.catRepo.findById(categoryId);
    if (cat == null) return;
    final ancestors = widget.catRepo.ancestorsOf(cat);
    setState(() {
      for (final a in ancestors) {
        _expanded.add(a.id);
      }
    });
  }

  void _toggleExpand(int id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      shrinkWrap: widget.maxHeight == null,
      children: widget.roots.map((r) => _buildNode(context, r, 0)).toList(),
    );

    if (widget.maxHeight != null) {
      return SizedBox(height: widget.maxHeight, child: list);
    }
    return list;
  }

  Widget _buildNode(BuildContext context, CategoryEntity cat, int depth) {
    final l10n = AppLocalizations.of(context)!;
    final children = widget.catRepo.listChildren(cat.id);
    final hasChildren = children.isNotEmpty;
    final expanded = _expanded.contains(cat.id);
    final selected = widget.selectedCategoryId == cat.id;
    final color = parseHexColor(cat.color);

    return Column(
      key: ValueKey('cat_node_${cat.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
          child: InkWell(
            onTap: widget.mode == CategoryTreeMode.select
                ? () => widget.onCategorySelected?.call(cat)
                : hasChildren
                    ? () => _toggleExpand(cat.id)
                    : null,
            child: Padding(
              padding: EdgeInsets.only(left: 12.0 + depth * 16, right: 8, top: 4, bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: hasChildren
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 22,
                            icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right, color: Colors.grey[700]),
                            onPressed: () => _toggleExpand(cat.id),
                          )
                        : Icon(categoryIcon(cat.icon), size: 18, color: color),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.normal,
                        fontSize: depth == 0 ? 15 : 14,
                      ),
                    ),
                  ),
                  if (widget.mode == CategoryTreeMode.select)
                    Radio<int>(
                      value: cat.id,
                      groupValue: widget.selectedCategoryId,
                      onChanged: (_) => widget.onCategorySelected?.call(cat),
                    )
                  else
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, size: 20),
                      onSelected: (action) async {
                        switch (action) {
                          case 'add':
                            if (widget.onAddSubCategory != null) await widget.onAddSubCategory!(cat);
                          case 'edit':
                            if (widget.onEditCategory != null) await widget.onEditCategory!(cat);
                          case 'delete':
                            if (widget.onDeleteCategory != null) await widget.onDeleteCategory!(cat);
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (cat.depth < CategoryRepository.maxDepth)
                          PopupMenuItem(value: 'add', child: Text(l10n.addSubCategory)),
                        PopupMenuItem(value: 'edit', child: Text(l10n.editCategory)),
                        PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                      ],
                    ),
                  if (widget.mode == CategoryTreeMode.manage && hasChildren)
                    IconButton(
                      icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                      onPressed: () => _toggleExpand(cat.id),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasChildren && expanded)
          ...children.map((c) => _buildNode(context, c, depth + 1)),
      ],
    );
  }
}

/// 添加/编辑图片时的分类选择区（含管理入口）
class CategoryPickerSection extends StatefulWidget {
  const CategoryPickerSection({
    super.key,
    required this.catRepo,
    required this.selectedCategoryId,
    required this.onSelected,
    required this.onOpenManage,
    required this.onAddCategory,
    this.maxTreeHeight = 280,
  });

  final CategoryRepository catRepo;
  final int? selectedCategoryId;
  final ValueChanged<CategoryEntity?> onSelected;
  final Future<void> Function() onOpenManage;
  final Future<void> Function() onAddCategory;
  final double maxTreeHeight;

  @override
  State<CategoryPickerSection> createState() => CategoryPickerSectionState();
}

class CategoryPickerSectionState extends State<CategoryPickerSection> {
  final GlobalKey<CategoryExpandableTreeState> _treeKey = GlobalKey();
  Set<int> _initialExpanded = {};

  @override
  void initState() {
    super.initState();
    _syncExpanded();
  }

  @override
  void didUpdateWidget(CategoryPickerSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCategoryId != oldWidget.selectedCategoryId) {
      _syncExpanded();
    }
  }

  void _syncExpanded() {
    if (widget.selectedCategoryId == null) return;
    final cat = widget.catRepo.findById(widget.selectedCategoryId!);
    if (cat == null) return;
    _initialExpanded = widget.catRepo.ancestorsOf(cat).map((e) => e.id).toSet();
  }

  void refreshTree() {
    _syncExpanded();
    setState(() {});
    if (widget.selectedCategoryId != null) {
      _treeKey.currentState?.expandToCategory(widget.selectedCategoryId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final roots = widget.catRepo.listRoots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.selectCategory, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.manageCategories,
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: () async {
                await widget.onOpenManage();
                refreshTree();
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.addRootCategory,
              icon: const Icon(Icons.add, size: 20),
              onPressed: () async {
                await widget.onAddCategory();
                refreshTree();
              },
            ),
            const Spacer(),
            TextButton(onPressed: () => widget.onSelected(null), child: Text(l10n.clearCategory)),
          ],
        ),
        const SizedBox(height: 4),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CategoryExpandableTree(
            key: _treeKey,
            catRepo: widget.catRepo,
            roots: roots,
            mode: CategoryTreeMode.select,
            selectedCategoryId: widget.selectedCategoryId,
            onCategorySelected: widget.onSelected,
            initialExpandedIds: _initialExpanded,
            maxHeight: widget.maxTreeHeight,
          ),
        ),
      ],
    );
  }
}
