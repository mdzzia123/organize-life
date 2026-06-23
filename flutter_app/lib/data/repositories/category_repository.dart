import '../../objectbox.g.dart';
import '../models/entities.dart';
import '../objectbox_store.dart';

class CategoryRepository {
  CategoryRepository(this._store);

  final ObjectBoxStore _store;
  static const maxDepth = 4; // 0-based, 5 levels total

  List<CategoryEntity> listAll() {
    final q = _store.categoryBox.query().order(CategoryEntity_.sortOrder).build();
    final list = q.find();
    q.close();
    return list;
  }

  List<CategoryEntity> listRoots() {
    final q = _store.categoryBox
        .query(CategoryEntity_.parentLocalId.equals(0))
        .order(CategoryEntity_.sortOrder)
        .build();
    final list = q.find();
    q.close();
    return list;
  }

  List<CategoryEntity> listChildren(int parentLocalId) {
    final q = _store.categoryBox
        .query(CategoryEntity_.parentLocalId.equals(parentLocalId))
        .order(CategoryEntity_.sortOrder)
        .build();
    final list = q.find();
    q.close();
    return list;
  }

  bool hasChildren(int categoryLocalId) {
    final q = _store.categoryBox.query(CategoryEntity_.parentLocalId.equals(categoryLocalId)).build();
    final c = q.count();
    q.close();
    return c > 0;
  }

  bool isLeaf(int categoryLocalId) => !hasChildren(categoryLocalId);

  CategoryEntity? findById(int id) => _store.categoryBox.get(id);

  CategoryEntity? findBySlug(String slug) {
    final q = _store.categoryBox.query(CategoryEntity_.slug.equals(slug)).build();
    final r = q.findFirst();
    q.close();
    return r;
  }

  CategoryEntity? findByCloudId(String cloudId) {
    if (cloudId.isEmpty) return null;
    final q = _store.categoryBox.query(CategoryEntity_.cloudId.equals(cloudId)).build();
    final r = q.findFirst();
    q.close();
    return r;
  }

  List<CategoryEntity> ancestorsOf(CategoryEntity cat) {
    final chain = <CategoryEntity>[];
    var current = cat;
    while (current.parentLocalId != 0) {
      final parent = findById(current.parentLocalId);
      if (parent == null) break;
      chain.insert(0, parent);
      current = parent;
    }
    return chain;
  }

  String pathLabel(CategoryEntity cat) {
    final parts = [...ancestorsOf(cat).map((c) => c.name), cat.name];
    return parts.join(' / ');
  }

  int save(CategoryEntity entity) {
    entity.updatedAt = DateTime.now();
    if (entity.id == 0) entity.createdAt = DateTime.now();
    return _store.categoryBox.put(entity);
  }

  CategoryEntity? createChild({
    required CategoryEntity parent,
    required String name,
    String icon = 'category',
    String color = '#607D8B',
    bool isSystem = false,
  }) {
    if (parent.depth >= maxDepth) return null;
    final entity = CategoryEntity()
      ..slug = 'custom_${DateTime.now().millisecondsSinceEpoch}'
      ..name = name.trim()
      ..icon = icon
      ..color = color
      ..parentLocalId = parent.id
      ..parentCloudId = parent.cloudId
      ..depth = parent.depth + 1
      ..sortOrder = listChildren(parent.id).length + 1
      ..isSystem = isSystem;
    save(entity);
    return entity;
  }

  CategoryEntity? createRoot({
    required String name,
    String icon = 'category',
    String color = '#607D8B',
  }) {
    final entity = CategoryEntity()
      ..slug = 'custom_${DateTime.now().millisecondsSinceEpoch}'
      ..name = name.trim()
      ..icon = icon
      ..color = color
      ..sortOrder = listRoots().length + 100
      ..isSystem = false;
    save(entity);
    return entity;
  }

  bool updateName(CategoryEntity entity, String name) {
    if (name.trim().isEmpty) return false;
    entity.name = name.trim();
    save(entity);
    return true;
  }

  bool delete(CategoryEntity entity) {
    if (hasChildren(entity.id)) return false;
    final items = _store.itemBox
        .query(ItemEntity_.categoryLocalId.equals(entity.id))
        .build()
        .find();
    if (items.isNotEmpty) return false;
    return _store.categoryBox.remove(entity.id);
  }

  int countItems(int categoryLocalId) {
    final q = _store.itemBox
        .query(ItemEntity_.categoryLocalId.equals(categoryLocalId))
        .build();
    final c = q.count();
    q.close();
    return c;
  }

  /// 含子分类的图片总数
  int countItemsRecursive(int categoryLocalId) {
    var total = countItems(categoryLocalId);
    for (final child in listChildren(categoryLocalId)) {
      total += countItemsRecursive(child.id);
    }
    return total;
  }

  int totalCategoryCount() => _store.categoryBox.count();

  int totalItemCount() => _store.itemBox.count();
}
