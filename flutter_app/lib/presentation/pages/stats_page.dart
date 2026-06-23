import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n_ext.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/entities.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  Map<String, int>? _storage;
  List<_CategoryStat>? _categories;
  Map<String, int>? _sync;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final itemRepo = await ref.read(itemRepoProvider.future);
    final catRepo = await ref.read(categoryRepoProvider.future);

    final storage = itemRepo.storageStats();
    final bytes = itemRepo.bytesByCategory();
    final sync = itemRepo.syncStats();

    final stats = <_CategoryStat>[];
    for (final cat in catRepo.listRoots()) {
      stats.add(_CategoryStat(
        category: cat,
        itemCount: catRepo.countItemsRecursive(cat.id),
        storageBytes: bytes[cat.id] ?? 0,
      ));
    }
    stats.sort((a, b) => b.itemCount.compareTo(a.itemCount));

    if (mounted) {
      setState(() {
        _storage = storage;
        _categories = stats;
        _sync = sync;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stats),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _storage == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    title: l10n.statsOverview,
                    rows: [
                      (l10n.statsTotalItems, l10n.itemsCount(_storage!['totalItems'] ?? 0)),
                      (l10n.statsWithImage, l10n.itemsCount(_storage!['withImage'] ?? 0)),
                      (l10n.statsLocalStorage, formatBytes(_storage!['bytes'] ?? 0)),
                      (l10n.statsSynced, l10n.itemsCount(_sync!['synced'] ?? 0)),
                      (l10n.statsSyncFailed, l10n.itemsCount(_sync!['failed'] ?? 0)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.perCategoryStats, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...(_categories ?? []).map(
                    (s) => _CategoryStatTile(stat: s, l10n: l10n),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CategoryStat {
  _CategoryStat({required this.category, required this.itemCount, required this.storageBytes});

  final CategoryEntity category;
  final int itemCount;
  final int storageBytes;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(r.$1, style: TextStyle(color: Colors.grey[700]))),
                    Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryStatTile extends StatelessWidget {
  const _CategoryStatTile({required this.stat, required this.l10n});

  final _CategoryStat stat;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(stat.category.color);
    final total = stat.itemCount;
    final maxHint = total > 0 ? total : 1;
    final name = categoryDisplayName(stat.category, l10n);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(categoryIcon(stat.category.icon), color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(l10n.itemsCount(total), style: TextStyle(color: Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stat.itemCount / maxHint,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.1),
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(formatBytes(stat.storageBytes), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
