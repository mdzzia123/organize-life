import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n_ext.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/entities.dart';
import 'item_detail_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  String _keyword = '';
  List<ItemEntity> _results = [];
  Map<int, CategoryEntity> _catMap = {};
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search([String? keyword]) async {
    final kw = (keyword ?? _controller.text).trim();
    setState(() {
      _keyword = kw;
      _loading = true;
    });

    final l10n = AppLocalizations.of(context)!;
    final colorKeys = matchColorKeys(kw, l10n);
    final itemRepo = await ref.read(itemRepoProvider.future);
    final catRepo = await ref.read(categoryRepoProvider.future);
    final results = kw.isEmpty
        ? itemRepo.listAll()
        : itemRepo.listAll(keyword: kw, colorKeys: colorKeys.isEmpty ? null : colorKeys);
    final cats = {for (final c in catRepo.listAll()) c.id: c};

    if (mounted) {
      setState(() {
        _results = results;
        _catMap = cats;
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(ItemEntity item) async {
    final l10n = AppLocalizations.of(context)!;
    final catRepo = await ref.read(categoryRepoProvider.future);
    final cat = _catMap[item.categoryLocalId];
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemDetailPage(
          item: item,
          categoryName: cat != null ? catRepo.pathLabel(cat) : l10n.unknownCategory,
        ),
      ),
    );
    if (changed == true) await _search(_keyword);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _search,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _search('');
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _keyword.isEmpty ? l10n.searchStartHint : l10n.searchNoResults(_keyword),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        l10n.searchResultsCount(_results.length),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final cat = _catMap[item.categoryLocalId];
                          return FutureBuilder(
                            future: ref.read(categoryRepoProvider.future),
                            builder: (context, snap) {
                              final path = cat != null && snap.hasData
                                  ? snap.data!.pathLabel(cat)
                                  : l10n.unknownCategory;
                              return _SearchResultTile(
                                item: item,
                                l10n: l10n,
                                categoryName: path,
                                categoryColor: cat != null ? parseHexColor(cat.color) : Colors.grey,
                                onTap: () => _openDetail(item),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.item,
    required this.l10n,
    required this.categoryName,
    required this.categoryColor,
    required this.onTap,
  });

  final ItemEntity item;
  final AppLocalizations l10n;
  final String categoryName;
  final Color categoryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.localImagePath.isNotEmpty && File(item.localImagePath).existsSync();
    return ListTile(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 52,
          height: 52,
          child: hasImage
              ? Image.file(File(item.localImagePath), fit: BoxFit.cover)
              : Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
        ),
      ),
      title: Text(item.title.isEmpty ? l10n.unnamed : item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.note.isNotEmpty)
            Text(item.note, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(categoryName, style: TextStyle(fontSize: 11, color: categoryColor)),
              ),
              const SizedBox(width: 6),
              SyncStatusBadge(status: item.syncStatus),
            ],
          ),
        ],
      ),
      isThreeLine: item.note.isNotEmpty,
    );
  }
}
