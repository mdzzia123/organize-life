import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:organize_life/data/objectbox_store.dart';
import 'package:organize_life/data/repositories/category_repository.dart';
import 'package:organize_life/data/repositories/item_repository.dart';
import 'package:organize_life/data/services/cloud_api_service.dart';
import 'package:organize_life/data/services/cloud_sync_service.dart';
import 'package:organize_life/data/services/payment_service.dart';

final objectBoxProvider = FutureProvider<ObjectBoxStore>((ref) async {
  final store = await ObjectBoxStore.open();
  ref.onDispose(() => store.close());
  return store;
});

final cloudApiProvider = Provider<CloudApiService>((ref) {
  final cloud = CloudApiService();
  cloud.init();
  return cloud;
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  final svc = PaymentService();
  svc.initWechat();
  return svc;
});

final categoryRepoProvider = FutureProvider<CategoryRepository>((ref) async {
  final store = await ref.watch(objectBoxProvider.future);
  return CategoryRepository(store);
});

final itemRepoProvider = FutureProvider<ItemRepository>((ref) async {
  final store = await ref.watch(objectBoxProvider.future);
  final cloud = ref.watch(cloudApiProvider);
  return ItemRepository(store, cloud);
});

final cloudSyncProvider = FutureProvider<CloudSyncService>((ref) async {
  final store = await ref.watch(objectBoxProvider.future);
  final cloud = ref.watch(cloudApiProvider);
  return CloudSyncService(cloud, CategoryRepository(store), await ref.watch(itemRepoProvider.future));
});

/// 启动时注册设备并同步云端分类 ID
final bootstrapProvider = FutureProvider<void>((ref) async {
  final cloud = ref.watch(cloudApiProvider);
  final store = await ref.watch(objectBoxProvider.future);
  final catRepo = CategoryRepository(store);

  try {
    await cloud.init();
    await cloud.registerDevice();
    final remoteCats = await cloud.listCategories();

    for (final remote in remoteCats) {
      final slug = remote['slug']?.toString() ?? '';
      final cloudId = remote['_id']?.toString() ?? '';
      if (slug.isEmpty || cloudId.isEmpty) continue;

      final local = catRepo.findByCloudId(cloudId) ?? catRepo.findBySlug(slug);
      if (local != null && local.cloudId.isEmpty) {
        local.cloudId = cloudId;
        catRepo.save(local);
      }
    }

    for (final remote in remoteCats) {
      final cloudId = remote['_id']?.toString() ?? '';
      final parentCloudId = remote['parentId']?.toString() ?? '';
      if (cloudId.isEmpty) continue;
      final local = catRepo.findByCloudId(cloudId);
      if (local == null) continue;
      local.depth = int.tryParse(remote['depth']?.toString() ?? '') ?? local.depth;
      if (parentCloudId.isNotEmpty) {
        final parent = catRepo.findByCloudId(parentCloudId);
        if (parent != null) {
          local.parentLocalId = parent.id;
          local.parentCloudId = parentCloudId;
        }
      }
      catRepo.save(local);
    }
  } catch (_) {
    // 离线模式：仅使用本地 ObjectBox
  }
});
