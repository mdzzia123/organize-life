import 'dart:io';

import '../../objectbox.g.dart';
import '../models/entities.dart';
import '../objectbox_store.dart';
import '../services/cloud_api_service.dart';

class ItemRepository {
  ItemRepository(this._store, this._cloud);

  final ObjectBoxStore _store;
  final CloudApiService _cloud;

  List<ItemEntity> listByCategory(int categoryLocalId, {String keyword = '', Set<String>? colorKeys}) {
    final q = _store.itemBox
        .query(ItemEntity_.categoryLocalId.equals(categoryLocalId))
        .order(ItemEntity_.updatedAt, flags: Order.descending)
        .build();
    var list = q.find();
    q.close();

    if (keyword.isNotEmpty || (colorKeys != null && colorKeys.isNotEmpty)) {
      list = list.where((e) => _matchesSearch(e, keyword, colorKeys)).toList();
    }
    return list;
  }

  ItemEntity? findById(int id) => _store.itemBox.get(id);

  ItemEntity? findByCloudId(String cloudId) {
    if (cloudId.isEmpty) return null;
    final q = _store.itemBox.query(ItemEntity_.cloudId.equals(cloudId)).build();
    final r = q.findFirst();
    q.close();
    return r;
  }

  void putLocal(ItemEntity item) {
    item.updatedAt = DateTime.now();
    if (item.id == 0) item.createdAt = DateTime.now();
    _store.itemBox.put(item);
  }

  List<ItemEntity> listAll({String keyword = '', Set<String>? colorKeys}) {
    final q = _store.itemBox.query().order(ItemEntity_.updatedAt, flags: Order.descending).build();
    var list = q.find();
    q.close();

    if (keyword.isNotEmpty || (colorKeys != null && colorKeys.isNotEmpty)) {
      list = list.where((e) => _matchesSearch(e, keyword, colorKeys)).toList();
    }
    return list;
  }

  bool _matchesSearch(ItemEntity e, String keyword, Set<String>? colorKeys) {
    final kw = keyword.trim().toLowerCase();
    final textMatch = kw.isEmpty ||
        e.title.toLowerCase().contains(kw) ||
        e.note.toLowerCase().contains(kw) ||
        e.tags.any((t) => t.toLowerCase().contains(kw)) ||
        e.colors.any((c) => c.toLowerCase().contains(kw));
    final colorMatch = colorKeys == null ||
        colorKeys.isEmpty ||
        e.colors.any((c) => colorKeys.contains(c));
    if (kw.isEmpty) return colorMatch;
    if (colorKeys == null || colorKeys.isEmpty) return textMatch;
    return textMatch || e.colors.any((c) => colorKeys.contains(c));
  }

  Map<String, int> storageStats() {
    final all = _store.itemBox.getAll();
    var bytes = 0;
    var withImage = 0;
    for (final item in all) {
      if (item.localImagePath.isEmpty) continue;
      final file = File(item.localImagePath);
      if (file.existsSync()) {
        bytes += file.lengthSync();
        withImage++;
      }
    }
    return {'totalItems': all.length, 'withImage': withImage, 'bytes': bytes};
  }

  Map<int, int> countByCategory() {
    final map = <int, int>{};
    for (final item in _store.itemBox.getAll()) {
      map[item.categoryLocalId] = (map[item.categoryLocalId] ?? 0) + 1;
    }
    return map;
  }

  Map<int, int> bytesByCategory() {
    final map = <int, int>{};
    for (final item in _store.itemBox.getAll()) {
      if (item.localImagePath.isEmpty) continue;
      final file = File(item.localImagePath);
      if (!file.existsSync()) continue;
      map[item.categoryLocalId] = (map[item.categoryLocalId] ?? 0) + file.lengthSync();
    }
    return map;
  }

  Future<ItemEntity> saveLocal({
    required ItemEntity item,
    bool syncToCloud = true,
    UploadProgressCallback? onProgress,
  }) async {
    item.updatedAt = DateTime.now();
    if (item.id == 0) item.createdAt = DateTime.now();
    _store.itemBox.put(item);

    if (!syncToCloud) return item;

    try {
      item.syncStatus = SyncStatus.pending;
      _store.itemBox.put(item);

      final cat = _store.categoryBox.get(item.categoryLocalId);
      if (cat == null) throw Exception('分类不存在');

      await _ensureCategorySynced(cat);

      // 系统分类首次使用时从云端拉取 cloudId
      String categoryCloudId = cat.cloudId;
      if (categoryCloudId.isEmpty) {
        final remoteCats = await _cloud.listCategories();
        final matched = remoteCats.cast<Map<String, dynamic>?>().firstWhere(
              (c) => c!['slug'] == cat.slug,
              orElse: () => null,
            );
        if (matched != null) {
          categoryCloudId = matched['_id']?.toString() ?? '';
          cat.cloudId = categoryCloudId;
          _store.categoryBox.put(cat);
        }
      }

      final result = await _cloud.saveItem(
        cloudId: item.cloudId.isEmpty ? null : item.cloudId,
        categoryCloudId: categoryCloudId,
        localId: item.id,
        title: item.title,
        note: item.note,
        tags: item.tags,
        colors: item.colors,
        localImagePath: item.localImagePath,
        fileID: item.cloudFileId.isEmpty ? null : item.cloudFileId,
        cloudPath: item.cloudPath.isEmpty ? null : item.cloudPath,
        onProgress: onProgress,
      );

      item.cloudId = result['id']?.toString() ?? item.cloudId;
      item.cloudFileId = result['fileID']?.toString() ?? item.cloudFileId;
      item.cloudPath = result['cloudPath']?.toString() ?? item.cloudPath;
      item.syncStatus = SyncStatus.synced;
    } catch (_) {
      item.syncStatus = SyncStatus.failed;
    }

    _store.itemBox.put(item);
    return item;
  }

  Future<void> delete(ItemEntity item, {bool syncToCloud = true}) async {
    if (syncToCloud && item.cloudId.isNotEmpty) {
      try {
        await _cloud.deleteItem(item.cloudId);
      } catch (_) {
        // 云端删除失败仍删本地，避免脏数据
      }
    }
    _store.itemBox.remove(item.id);
  }

  Future<void> retrySync(ItemEntity item, {UploadProgressCallback? onProgress}) =>
      saveLocal(item: item, syncToCloud: true, onProgress: onProgress);

  List<ItemEntity> listNeedSync() {
    return _store.itemBox.getAll().where((e) {
      return e.syncStatus == SyncStatus.failed || e.syncStatus == SyncStatus.pending;
    }).toList();
  }

  Future<int> retryAllFailed() async {
    final items = listNeedSync();
    var ok = 0;
    for (final item in items) {
      await saveLocal(item: item, syncToCloud: true);
      if (item.syncStatus == SyncStatus.synced) ok++;
    }
    return ok;
  }

  Future<void> _ensureCategorySynced(CategoryEntity cat) async {
    if (cat.cloudId.isNotEmpty) return;
    if (cat.parentLocalId != 0) {
      final parent = _store.categoryBox.get(cat.parentLocalId);
      if (parent != null) {
        await _ensureCategorySynced(parent);
        cat.parentCloudId = parent.cloudId;
      }
    }
    cat.cloudId = await _cloud.saveCategory(
      slug: cat.slug,
      name: cat.name,
      icon: cat.icon,
      color: cat.color,
      sortOrder: cat.sortOrder,
      parentCloudId: cat.parentCloudId.isEmpty ? null : cat.parentCloudId,
      depth: cat.depth,
      isSystem: cat.isSystem,
    );
    _store.categoryBox.put(cat);
  }

  Map<String, int> syncStats() {
    final all = _store.itemBox.getAll();
    return {
      'total': all.length,
      'synced': all.where((e) => e.syncStatus == SyncStatus.synced).length,
      'failed': all.where((e) => e.syncStatus == SyncStatus.failed).length,
      'pending': all.where((e) => e.syncStatus == SyncStatus.pending).length,
    };
  }
}
