import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../objectbox.g.dart';
import 'models/category_presets.dart';
import 'models/entities.dart';

class ObjectBoxStore {
  ObjectBoxStore._(this.store);

  final Store store;
  late final Box<CategoryEntity> categoryBox;
  late final Box<ItemEntity> itemBox;

  static ObjectBoxStore? _instance;
  static const _treeVersionKey = 'ol_category_tree_version';
  static const currentTreeVersion = 2;

  static Future<ObjectBoxStore> open() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    final store = await openStore(directory: p.join(dir.path, 'objectbox'));
    final instance = ObjectBoxStore._(store);
    instance.categoryBox = store.box<CategoryEntity>();
    instance.itemBox = store.box<ItemEntity>();
    await instance._initCategories();
    _instance = instance;
    return instance;
  }

  Future<void> _initCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getInt(_treeVersionKey) ?? 0;

    if (categoryBox.count() == 0) {
      await _seedPresetTree();
      await prefs.setInt(_treeVersionKey, currentTreeVersion);
      return;
    }

    if (version < currentTreeVersion) {
      await _migrateToTreeV2();
      await prefs.setInt(_treeVersionKey, currentTreeVersion);
    }
  }

  Future<void> _seedPresetTree() async {
    final flat = flattenPresets(categoryPresetTree);
    final slugToId = <String, int>{};

    for (final entry in flat) {
      final n = entry.node;
      final parentLocalId = entry.parentSlug == null ? 0 : (slugToId[entry.parentSlug!] ?? 0);
      final entity = CategoryEntity()
        ..slug = entry.slug
        ..name = n.name
        ..icon = entry.depth == 0 ? n.icon : 'subcategory'
        ..color = entry.depth == 0 ? n.color : _rootColor(entry.slug, flat)
        ..sortOrder = n.sortOrder
        ..parentLocalId = parentLocalId
        ..depth = entry.depth
        ..isSystem = true;
      slugToId[entry.slug] = categoryBox.put(entity);
    }
  }

  String _rootColor(String slug, List<({CategoryPresetNode node, String slug, String? parentSlug, int depth})> flat) {
    var current = slug;
    while (true) {
      final entry = flat.firstWhere((e) => e.slug == current);
      if (entry.depth == 0) return entry.node.color;
      if (entry.parentSlug == null) return '#607D8B';
      current = entry.parentSlug!;
    }
  }

  Future<void> _migrateToTreeV2() async {
    final allCats = categoryBox.getAll();
    final customCats = allCats.where((c) => c.slug.startsWith('custom_')).toList();
    final items = itemBox.getAll();
    final itemCatSlug = <int, String>{};
    for (final item in items) {
      CategoryEntity? cat;
      for (final c in allCats) {
        if (c.id == item.categoryLocalId) {
          cat = c;
          break;
        }
      }
      if (cat != null) itemCatSlug[item.id] = cat.slug;
    }

    categoryBox.removeAll();
    await _seedPresetTree();

    var slugToEntity = {for (final c in categoryBox.getAll()) c.slug: c};

    for (final custom in customCats) {
      final entity = CategoryEntity()
        ..slug = custom.slug
        ..name = custom.name
        ..icon = custom.icon
        ..color = custom.color
        ..sortOrder = custom.sortOrder + 200
        ..cloudId = custom.cloudId
        ..isSystem = false;
      categoryBox.put(entity);
    }
    slugToEntity = {for (final c in categoryBox.getAll()) c.slug: c};

    for (final item in items) {
      final oldSlug = itemCatSlug[item.id];
      if (oldSlug == null) continue;
      CategoryEntity? target;
      if (slugToEntity.containsKey(oldSlug)) {
        target = slugToEntity[oldSlug];
      } else {
        final mapped = legacyRootSlugMap[oldSlug.split('_').first] ?? legacyRootSlugMap[oldSlug];
        if (mapped != null) target = slugToEntity[mapped];
      }
      if (target != null) {
        item
          ..categoryLocalId = target.id
          ..categoryCloudId = target.cloudId;
        itemBox.put(item);
      }
    }
  }

  void close() {
    store.close();
    _instance = null;
  }
}
