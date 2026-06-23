import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n_ext.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/entities.dart';
import '../../data/repositories/category_repository.dart';
import 'add_item_page.dart';
import 'category_browse_page.dart';
import 'category_items_page.dart';
import 'manage_categories_page.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    ref.read(bootstrapProvider.future);
  }

  Future<void> _refresh() async {
    await ref.read(bootstrapProvider.future);
    setState(() => _refreshKey++);
  }

  Future<void> _openCategory(CategoryEntity cat, CategoryRepository catRepo) async {
    if (catRepo.hasChildren(cat.id)) {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => CategoryBrowsePage(parent: cat)),
      );
      if (changed == true) await _refresh();
    } else {
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => CategoryItemsPage(category: cat)),
      );
      if (changed == true) await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catRepoAsync = ref.watch(categoryRepoProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        title: Text(l10n.appTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.search,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: l10n.stats,
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsPage()));
              await _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            tooltip: l10n.manageCategories,
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCategoriesPage()));
              await _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: catRepoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.initFailed(e.toString()))),
        data: (catRepo) {
          final categories = catRepo.listRoots();
          if (categories.isEmpty) return Center(child: Text(l10n.noCategories));
          final totalItems = catRepo.totalItemCount();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      l10n.categoriesSummary(catRepo.totalCategoryCount(), totalItems),
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
                        final count = isLeaf ? catRepo.countItems(cat.id) : catRepo.countItemsRecursive(cat.id);
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final changed = await openAddItemFlow(context, ref);
          if (changed == true) await _refresh();
        },
        child: const Icon(Icons.add),
      ),
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
                    child: Text(l10n.itemsCount(itemCount), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ),
                  if (hasChildren) Icon(Icons.chevron_right, size: 16, color: Colors.grey[500]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
