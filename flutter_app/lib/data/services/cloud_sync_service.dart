import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/entities.dart';
import '../repositories/category_repository.dart';
import '../repositories/item_repository.dart';
import 'cloud_api_service.dart';

class CloudPullProgress {
  const CloudPullProgress({
    required this.phase,
    required this.current,
    required this.total,
    this.detail = '',
  });

  final String phase;
  final int current;
  final int total;
  final String detail;

  double get ratio => total > 0 ? current / total : 0;
}

class CloudPullResult {
  CloudPullResult({
    this.categoriesSynced = 0,
    this.itemsDownloaded = 0,
    this.itemsUpdated = 0,
    this.itemsSkipped = 0,
    this.errors = const [],
  });

  final int categoriesSynced;
  final int itemsDownloaded;
  final int itemsUpdated;
  final int itemsSkipped;
  final List<String> errors;

  int get totalProcessed => itemsDownloaded + itemsUpdated + itemsSkipped;
}

class CloudSyncService {
  CloudSyncService(this._cloud, this._catRepo, this._itemRepo, {Dio? dio})
      : _dio = dio ?? Dio();

  final CloudApiService _cloud;
  final CategoryRepository _catRepo;
  final ItemRepository _itemRepo;
  final Dio _dio;

  Future<CloudPullResult> pullFromCloud({
    void Function(CloudPullProgress progress)? onProgress,
  }) async {
    final errors = <String>[];
    var categoriesSynced = 0;
    var itemsDownloaded = 0;
    var itemsUpdated = 0;
    var itemsSkipped = 0;

    onProgress?.call(const CloudPullProgress(phase: '连接云端', current: 0, total: 1));
    await _cloud.registerDevice();

    onProgress?.call(const CloudPullProgress(phase: '同步分类', current: 0, total: 1));
    final remoteCats = await _cloud.listCategories();
    categoriesSynced = _mergeCategories(remoteCats);

    onProgress?.call(const CloudPullProgress(phase: '拉取条目列表', current: 0, total: 1));
    final remoteItems = await _cloud.listAllItems();

    for (var i = 0; i < remoteItems.length; i++) {
      final remote = remoteItems[i];
      onProgress?.call(CloudPullProgress(
        phase: '下载图片',
        current: i + 1,
        total: remoteItems.length,
        detail: remote['title']?.toString() ?? '',
      ));

      try {
        final outcome = await _importRemoteItem(remote);
        switch (outcome) {
          case _ImportOutcome.downloaded:
            itemsDownloaded++;
          case _ImportOutcome.updated:
            itemsUpdated++;
          case _ImportOutcome.skipped:
            itemsSkipped++;
        }
      } catch (e) {
        final id = remote['_id']?.toString() ?? '?';
        errors.add('$id: $e');
      }
    }

    return CloudPullResult(
      categoriesSynced: categoriesSynced,
      itemsDownloaded: itemsDownloaded,
      itemsUpdated: itemsUpdated,
      itemsSkipped: itemsSkipped,
      errors: errors,
    );
  }

  int _mergeCategories(List<Map<String, dynamic>> remoteCats) {
    var synced = 0;
    for (final rc in remoteCats) {
      final cloudId = rc['_id']?.toString() ?? '';
      final slug = rc['slug']?.toString() ?? '';
      if (cloudId.isEmpty) continue;

      var local = _catRepo.findByCloudId(cloudId) ?? (slug.isNotEmpty ? _catRepo.findBySlug(slug) : null);
      if (local != null) {
        if (local.cloudId.isEmpty) {
          local.cloudId = cloudId;
          _catRepo.save(local);
          synced++;
        }
        continue;
      }

      final parentCloudId = rc['parentId']?.toString() ?? '';
      var parentLocalId = 0;
      if (parentCloudId.isNotEmpty) {
        final parentLocal = _catRepo.findByCloudId(parentCloudId);
        if (parentLocal != null) parentLocalId = parentLocal.id;
      }

      final entity = CategoryEntity()
        ..cloudId = cloudId
        ..slug = slug.isNotEmpty ? slug : 'custom_$cloudId'
        ..name = rc['name']?.toString() ?? '未命名'
        ..icon = rc['icon']?.toString() ?? 'category'
        ..color = rc['color']?.toString() ?? '#607D8B'
        ..sortOrder = int.tryParse(rc['sortOrder']?.toString() ?? '') ?? 100
        ..parentLocalId = parentLocalId
        ..parentCloudId = parentCloudId
        ..depth = int.tryParse(rc['depth']?.toString() ?? '') ?? 0
        ..isSystem = rc['isSystem'] == true;
      _catRepo.save(entity);
      synced++;
    }
    return synced;
  }

  Future<_ImportOutcome> _importRemoteItem(Map<String, dynamic> remote) async {
    final cloudId = remote['_id']?.toString() ?? '';
    if (cloudId.isEmpty) return _ImportOutcome.skipped;

    final categoryCloudId = remote['categoryId']?.toString() ?? '';
    final cat = _catRepo.findByCloudId(categoryCloudId);
    if (cat == null) throw Exception('分类不存在: $categoryCloudId');

    final existing = _itemRepo.findByCloudId(cloudId);
    final tempUrl = remote['tempUrl']?.toString() ?? '';
    final fileId = remote['fileID']?.toString() ?? '';
    final needDownload = existing == null ||
        existing.localImagePath.isEmpty ||
        !File(existing.localImagePath).existsSync();

    String? localPath = existing?.localImagePath;
    if (needDownload) {
      if (tempUrl.isEmpty) throw Exception('无可用图片链接');
      localPath = await _downloadImage(tempUrl, cloudId);
    }

    if (existing != null) {
      existing
        ..title = remote['title']?.toString() ?? existing.title
        ..note = remote['note']?.toString() ?? existing.note
        ..categoryLocalId = cat.id
        ..categoryCloudId = categoryCloudId
        ..cloudFileId = fileId.isNotEmpty ? fileId : existing.cloudFileId
        ..cloudPath = remote['cloudPath']?.toString() ?? existing.cloudPath
        ..tags = List<String>.from(remote['tags'] ?? existing.tags)
        ..colors = List<String>.from(remote['colors'] ?? existing.colors)
        ..syncStatus = SyncStatus.synced
        ..updatedAt = DateTime.now();
      if (localPath != null && localPath.isNotEmpty) {
        existing.localImagePath = localPath;
      }
      _itemRepo.putLocal(existing);
      return needDownload ? _ImportOutcome.updated : _ImportOutcome.skipped;
    }

    final item = ItemEntity()
      ..cloudId = cloudId
      ..categoryLocalId = cat.id
      ..categoryCloudId = categoryCloudId
      ..title = remote['title']?.toString() ?? ''
      ..note = remote['note']?.toString() ?? ''
      ..localImagePath = localPath ?? ''
      ..cloudFileId = fileId
      ..cloudPath = remote['cloudPath']?.toString() ?? ''
      ..tags = List<String>.from(remote['tags'] ?? [])
      ..colors = List<String>.from(remote['colors'] ?? [])
      ..syncStatus = SyncStatus.synced
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    _itemRepo.putLocal(item);
    return _ImportOutcome.downloaded;
  }

  Future<String> _downloadImage(String url, String cloudId) async {
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'images'));
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

    final ext = _extFromUrl(url);
    final dest = File(p.join(imagesDir.path, 'cloud_$cloudId$ext'));
    if (await dest.exists()) return dest.path;

    final res = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 60)),
    );
    await dest.writeAsBytes(res.data ?? [], flush: true);
    return dest.path;
  }

  String _extFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? '';
    final ext = p.extension(path);
    if (ext.isNotEmpty && ext.length <= 5) return ext;
    return '.jpg';
  }
}

enum _ImportOutcome { downloaded, updated, skipped }
