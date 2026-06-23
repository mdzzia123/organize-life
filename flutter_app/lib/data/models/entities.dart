import 'package:objectbox/objectbox.dart';

/// 同步状态
enum SyncStatus {
  localOnly, // 仅本地
  pending,   // 待上传
  synced,    // 已同步
  failed,    // 同步失败
}

@Entity()
class CategoryEntity {
  @Id()
  int id = 0;

  /// 云端 _id（同步后写入）
  @Index()
  String cloudId = '';

  /// 唯一标识 slug，如 clothing / custom_xxx
  @Index()
  String slug = '';

  String name = '';
  String icon = 'category';
  String color = '#607D8B';
  int sortOrder = 100;

  /// 父分类本地 id，0 表示根分类
  int parentLocalId = 0;

  /// 父分类云端 id
  @Index()
  String parentCloudId = '';

  /// 层级深度 0=一级 … 4=五级
  int depth = 0;

  /// 预设分类（可编辑/删除）
  bool isSystem = false;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();
}

@Entity()
class ItemEntity {
  @Id()
  int id = 0;

  @Index()
  String cloudId = '';

  /// 关联 CategoryEntity.id（本地）
  int categoryLocalId = 0;

  /// 关联云端 category _id
  @Index()
  String categoryCloudId = '';

  String title = '';
  String note = '';

  /// 本地图片绝对路径
  String localImagePath = '';

  /// 云端 fileID / cloudPath
  String cloudFileId = '';
  String cloudPath = '';

  /// 标签，逗号分隔存储
  String tagsRaw = '';

  /// 颜色系 key，逗号分隔（如 black,white,grey）
  String colorsRaw = '';

  int syncStatusIndex = SyncStatus.localOnly.index;

  @Property(type: PropertyType.date)
  DateTime createdAt = DateTime.now();

  @Property(type: PropertyType.date)
  DateTime updatedAt = DateTime.now();

  @Transient()
  SyncStatus get syncStatus => SyncStatus.values[syncStatusIndex];

  set syncStatus(SyncStatus v) => syncStatusIndex = v.index;

  List<String> get tags =>
      tagsRaw.isEmpty ? [] : tagsRaw.split(',').where((e) => e.isNotEmpty).toList();

  set tags(List<String> v) => tagsRaw = v.join(',');

  List<String> get colors =>
      colorsRaw.isEmpty ? [] : colorsRaw.split(',').where((e) => e.isNotEmpty).toList();

  set colors(List<String> v) => colorsRaw = v.join(',');
}
