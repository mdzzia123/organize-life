import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../data/models/entities.dart';
import '../../../data/repositories/category_repository.dart';

/// 分类增删改及云端同步
class CategoryEditor {
  CategoryEditor(this.ref);

  final WidgetRef ref;

  Future<String?> promptName(
    BuildContext context, {
    String? initial,
    required String title,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: initial ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l10n.categoryName, border: const OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    if (ok != true) return null;
    final name = ctrl.text.trim();
    return name.isEmpty ? null : name;
  }

  Future<void> syncToCloud(CategoryEntity cat) async {
    final cloud = ref.read(cloudApiProvider);
    try {
      if (cat.parentLocalId != 0) {
        final catRepo = await ref.read(categoryRepoProvider.future);
        final parent = catRepo.findById(cat.parentLocalId);
        if (parent != null && parent.cloudId.isEmpty) {
          await syncToCloud(parent);
          cat.parentCloudId = parent.cloudId;
        }
      }
      final cloudId = await cloud.saveCategory(
        cloudId: cat.cloudId.isEmpty ? null : cat.cloudId,
        slug: cat.slug,
        name: cat.name,
        icon: cat.icon,
        color: cat.color,
        sortOrder: cat.sortOrder,
        parentCloudId: cat.parentCloudId.isEmpty ? null : cat.parentCloudId,
        depth: cat.depth,
        isSystem: cat.isSystem,
      );
      if (cloudId.isNotEmpty) {
        cat.cloudId = cloudId;
        final catRepo = await ref.read(categoryRepoProvider.future);
        catRepo.save(cat);
      }
    } catch (_) {}
  }

  Future<CategoryEntity?> addRoot(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptName(context, title: l10n.addRootCategory);
    if (name == null) return null;
    final catRepo = await ref.read(categoryRepoProvider.future);
    final entity = catRepo.createRoot(name: name);
    if (entity == null) return null;
    await syncToCloud(entity);
    return entity;
  }

  Future<CategoryEntity?> addChild(BuildContext context, CategoryEntity parent) async {
    final l10n = AppLocalizations.of(context)!;
    if (parent.depth >= CategoryRepository.maxDepth) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.categoryDepthLimit)));
      }
      return null;
    }
    final name = await promptName(context, title: l10n.addSubCategory);
    if (name == null) return null;
    final catRepo = await ref.read(categoryRepoProvider.future);
    final entity = catRepo.createChild(parent: parent, name: name);
    if (entity == null) return null;
    await syncToCloud(entity);
    return entity;
  }

  Future<bool> editCategory(BuildContext context, CategoryEntity cat) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await promptName(context, initial: cat.name, title: l10n.editCategory);
    if (name == null) return false;
    final catRepo = await ref.read(categoryRepoProvider.future);
    catRepo.updateName(cat, name);
    await syncToCloud(cat);
    return true;
  }

  Future<bool> deleteCategory(BuildContext context, CategoryEntity cat) async {
    final l10n = AppLocalizations.of(context)!;
    final catRepo = await ref.read(categoryRepoProvider.future);
    if (catRepo.hasChildren(cat.id)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.hasSubCategories)));
      }
      return false;
    }
    if (catRepo.countItems(cat.id) > 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.categoryNotEmpty)));
      }
      return false;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteCategory),
        content: Text(l10n.deleteCategoryConfirm(cat.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return false;
    if (cat.cloudId.isNotEmpty) {
      try {
        await ref.read(cloudApiProvider).deleteCategory(cat.cloudId);
      } catch (_) {}
    }
    catRepo.delete(cat);
    return true;
  }
}
