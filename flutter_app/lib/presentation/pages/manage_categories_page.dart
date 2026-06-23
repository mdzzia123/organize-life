import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../widgets/category_tree/category_editor.dart';
import '../widgets/category_tree/category_expandable_tree.dart';

class ManageCategoriesPage extends ConsumerStatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  ConsumerState<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends ConsumerState<ManageCategoriesPage> {
  int _refreshKey = 0;

  Future<void> _refresh() async => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final editor = CategoryEditor(ref);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        title: Text(l10n.manageCategories),
      ),
      body: FutureBuilder(
        key: ValueKey(_refreshKey),
        future: ref.read(categoryRepoProvider.future),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final catRepo = snap.data!;
          final roots = catRepo.listRoots();

          return CategoryExpandableTree(
            catRepo: catRepo,
            roots: roots,
            mode: CategoryTreeMode.manage,
            onEditCategory: (cat) async {
              await editor.editCategory(context, cat);
              await _refresh();
            },
            onDeleteCategory: (cat) async {
              await editor.deleteCategory(context, cat);
              await _refresh();
            },
            onAddSubCategory: (parent) async {
              await editor.addChild(context, parent);
              await _refresh();
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await editor.addRoot(context);
          await _refresh();
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.addRootCategory),
      ),
    );
  }
}
