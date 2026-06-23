import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n_ext.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/entities.dart';
import '../../data/repositories/category_repository.dart';
import 'add_item_page.dart';
import 'category_items_page.dart';

/// 分类浏览页：展示某层子分类网格，可继续下钻或进入图片列表（叶子节点）
class CategoryBrowsePage extends ConsumerStatefulWidget {
  const CategoryBrowsePage({
    super.key,
    this.parent,
    this.title,
  });

  /// null 表示根分类
  final CategoryEntity? parent;
  final String? title;

  @override
  ConsumerState<CategoryBrowsePage> createState() => _CategoryBrowsePageState();
}

class _CategoryBrowsePageState extends ConsumerState<CategoryBrowsePage> {
  int _refreshKey = 0;

  Future<void> _refresh() async {
    setState(() => _refreshKey++);
  }

  Future<void> _openCategory(CategoryEntity cat, CategoryRepository catRepo) async {
    if (catRepo.hasChildren(cat.id)) {
      final l10n = AppLocalizations.of(context)!;
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryBrowsePage(
            parent: cat,
            title: categoryDisplayName(cat, l10n),
          ),
        ),
      );
      if (changed == true) await _refresh();
    } else {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CategoryItemsPage(category: cat),
        ),
      );
      if (changed == true) await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catRepoAsync = ref.watch(categoryRepoProvider);

    return catRepoAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(l10n.initFailed(e.toString())))),
      data: (catRepo) {
        final parent = widget.parent;
        final categories = parent == null ? catRepo.listRoots() : catRepo.listChildren(parent.id);
        final pageTitle = widget.title ?? l10n.appTitle;

        if (categories.isEmpty && parent != null && catRepo.isLeaf(parent.id)) {
          return CategoryItemsPage(category: parent);
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            title: Text(pageTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final changed = await openAddItemFlow(context, ref, initialCategory: parent);
              if (changed == true) await _refresh();
            },
            child: const Icon(Icons.add),
          ),
          body: categories.isEmpty
              ? Center(child: Text(l10n.noCategories))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (parent != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Text(
                              l10n.subCategoriesHint(categories.length),
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverGrid(
                          key: ValueKey(_refreshKey),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final cat = categories[index];
                              final isLeaf = catRepo.isLeaf(cat.id);
                              final count = isLeaf
                                  ? catRepo.countItems(cat.id)
                                  : catRepo.countItemsRecursive(cat.id);
                              return _CategoryCard(
                                category: cat,
                                displayName: categoryDisplayName(cat, l10n),
                                itemCount: count,
                                hasChildren: !isLeaf,
                                onTap: () => _openCategory(cat, catRepo),
                              );
                            },
                            childCount: categories.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.displayName,
    required this.itemCount,
    required this.hasChildren,
    required this.onTap,
  });

  final CategoryEntity category;
  final String displayName;
  final int itemCount;
  final bool hasChildren;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = parseHexColor(category.color);
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(categoryIcon(category.icon), color: color, size: 20),
              ),
              const Spacer(),
              Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.itemsCount(itemCount),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ),
                  if (hasChildren)
                    Icon(Icons.chevron_right, size: 16, color: Colors.grey[500]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
