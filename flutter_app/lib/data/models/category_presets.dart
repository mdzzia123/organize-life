/// 预设分类树节点（最多 5 级）
class CategoryPresetNode {
  const CategoryPresetNode({
    required this.slug,
    required this.name,
    this.icon = 'category',
    this.color = '#607D8B',
    this.sortOrder = 0,
    this.children = const [],
  });

  final String slug;
  final String name;
  final String icon;
  final String color;
  final int sortOrder;
  final List<CategoryPresetNode> children;
}

/// 三级衣物子分类
const _clothingTypes = [
  CategoryPresetNode(slug: 'outerwear', name: '外套', sortOrder: 1),
  CategoryPresetNode(slug: 'innerwear', name: '内搭', sortOrder: 2),
  CategoryPresetNode(slug: 'pants', name: '裤子', sortOrder: 3),
  CategoryPresetNode(slug: 'dress', name: '连衣裙', sortOrder: 4),
  CategoryPresetNode(slug: 'skirt', name: '半裙', sortOrder: 5),
];

const _jewelryTypes = [
  CategoryPresetNode(slug: 'earrings', name: '耳饰', sortOrder: 1),
  CategoryPresetNode(slug: 'necklace', name: '项链', sortOrder: 2),
  CategoryPresetNode(slug: 'ring', name: '戒指', sortOrder: 3),
];

/// 完整预设分类树（1 级 = depth 0）
const categoryPresetTree = [
  CategoryPresetNode(
    slug: 'wardrobe',
    name: '衣橱',
    icon: 'checkroom',
    color: '#5B8DEF',
    sortOrder: 1,
    children: [
      CategoryPresetNode(
        slug: 'winter',
        name: '冬季',
        sortOrder: 1,
        children: _clothingTypes,
      ),
      CategoryPresetNode(
        slug: 'spring_autumn',
        name: '春秋',
        sortOrder: 2,
        children: _clothingTypes,
      ),
      CategoryPresetNode(
        slug: 'summer',
        name: '夏季',
        sortOrder: 3,
        children: _clothingTypes,
      ),
    ],
  ),
  CategoryPresetNode(
    slug: 'cosmetics',
    name: '化妆品',
    icon: 'face',
    color: '#E87BA0',
    sortOrder: 2,
    children: [
      CategoryPresetNode(slug: 'skincare', name: '护肤', sortOrder: 1),
      CategoryPresetNode(
        slug: 'makeup',
        name: '彩妆',
        sortOrder: 2,
        children: [
          CategoryPresetNode(slug: 'eyeshadow', name: '眼影类', sortOrder: 1),
          CategoryPresetNode(slug: 'makeup_tools', name: '工具类', sortOrder: 2),
        ],
      ),
    ],
  ),
  CategoryPresetNode(
    slug: 'jewelry',
    name: '首饰',
    icon: 'diamond',
    color: '#AB47BC',
    sortOrder: 3,
    children: [
      CategoryPresetNode(slug: 'gold', name: '黄金', sortOrder: 1, children: _jewelryTypes),
      CategoryPresetNode(slug: 'jade', name: '玉石', sortOrder: 2, children: _jewelryTypes),
      CategoryPresetNode(slug: 'kgold', name: 'K金', sortOrder: 3, children: _jewelryTypes),
    ],
  ),
  CategoryPresetNode(
    slug: 'health',
    name: '健康',
    icon: 'medical_services',
    color: '#4CAF88',
    sortOrder: 4,
    children: [
      CategoryPresetNode(
        slug: 'hospital_reports',
        name: '医院检查报告',
        sortOrder: 1,
        children: [CategoryPresetNode(slug: 'department', name: '科室', sortOrder: 1)],
      ),
      CategoryPresetNode(
        slug: 'home_medicine',
        name: '家有药品',
        sortOrder: 2,
        children: [
          CategoryPresetNode(slug: 'cold_medicine', name: '感冒药', sortOrder: 1),
          CategoryPresetNode(slug: 'chinese_medicine', name: '中成药', sortOrder: 2),
          CategoryPresetNode(slug: 'anti_inflammatory', name: '消炎药', sortOrder: 3),
        ],
      ),
    ],
  ),
  CategoryPresetNode(
    slug: 'documents',
    name: '证件',
    icon: 'badge',
    color: '#F5A623',
    sortOrder: 5,
    children: [
      CategoryPresetNode(slug: 'id_card', name: '身份证', sortOrder: 1),
      CategoryPresetNode(slug: 'driver_license', name: '驾驶证', sortOrder: 2),
      CategoryPresetNode(
        slug: 'qualification',
        name: '学历工作资质',
        sortOrder: 3,
        children: [
          CategoryPresetNode(slug: 'graduation_cert', name: '毕业证书', sortOrder: 1),
          CategoryPresetNode(slug: 'skill_cert', name: '技能证书', sortOrder: 2),
        ],
      ),
    ],
  ),
  CategoryPresetNode(
    slug: 'assets',
    name: '资产',
    icon: 'account_balance',
    color: '#795548',
    sortOrder: 6,
    children: [
      CategoryPresetNode(slug: 'insurance', name: '保险单据', sortOrder: 1),
      CategoryPresetNode(slug: 'property_deed', name: '房产证', sortOrder: 2),
      CategoryPresetNode(slug: 'finance', name: '银行证券', sortOrder: 3),
    ],
  ),
  CategoryPresetNode(
    slug: 'collections',
    name: '收藏爱好类',
    icon: 'collections',
    color: '#9C27B0',
    sortOrder: 7,
    children: [
      CategoryPresetNode(slug: 'tea_set', name: '茶具', sortOrder: 1),
      CategoryPresetNode(slug: 'calligraphy', name: '字画', sortOrder: 2),
      CategoryPresetNode(
        slug: 'figures',
        name: '手办',
        sortOrder: 3,
        children: [CategoryPresetNode(slug: 'books', name: '书籍', sortOrder: 1)],
      ),
    ],
  ),
  CategoryPresetNode(
    slug: 'furniture_home',
    name: '家具家居',
    icon: 'chair',
    color: '#8D6E63',
    sortOrder: 8,
    children: [
      CategoryPresetNode(slug: 'master_bedroom', name: '主卧', sortOrder: 1),
      CategoryPresetNode(slug: 'living_room', name: '客厅', sortOrder: 2),
      CategoryPresetNode(slug: 'appliances', name: '大家电', sortOrder: 3),
    ],
  ),
  CategoryPresetNode(
    slug: 'kitchen',
    name: '厨房',
    icon: 'kitchen',
    color: '#FF7043',
    sortOrder: 9,
    children: [
      CategoryPresetNode(slug: 'kitchen_appliances', name: '厨电', sortOrder: 1),
      CategoryPresetNode(slug: 'tableware', name: '餐具', sortOrder: 2),
      CategoryPresetNode(slug: 'kitchen_tools', name: '工具', sortOrder: 3),
    ],
  ),
  CategoryPresetNode(
    slug: 'digital',
    name: '数码',
    icon: 'devices',
    color: '#2196F3',
    sortOrder: 10,
    children: [
      CategoryPresetNode(slug: 'computer', name: '电脑', sortOrder: 1),
      CategoryPresetNode(slug: 'wearables', name: '个人电子穿戴', sortOrder: 2),
      CategoryPresetNode(slug: 'accessories', name: '配件', sortOrder: 3),
    ],
  ),
];

/// 旧版 slug → 新版根 slug（用于数据迁移）
const legacyRootSlugMap = {
  'clothing': 'wardrobe',
  'cosmetics': 'cosmetics',
  'medical': 'health',
  'documents': 'documents',
  'kitchen': 'kitchen',
  'furniture': 'furniture_home',
  'other': 'collections',
};

/// 扁平化预设，slug 为路径形式：wardrobe_winter_outerwear
List<({CategoryPresetNode node, String slug, String? parentSlug, int depth})> flattenPresets(
  List<CategoryPresetNode> roots,
) {
  final out = <({CategoryPresetNode node, String slug, String? parentSlug, int depth})>[];

  void walk(List<CategoryPresetNode> nodes, String? parentPath, int depth) {
    for (final n in nodes) {
      final path = parentPath == null ? n.slug : '${parentPath}_${n.slug}';
      out.add((node: n, slug: path, parentSlug: parentPath, depth: depth));
      if (n.children.isNotEmpty) walk(n.children, path, depth + 1);
    }
  }

  walk(roots, null, 0);
  return out;
}
