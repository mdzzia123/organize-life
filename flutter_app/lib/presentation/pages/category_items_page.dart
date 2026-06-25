import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_background.dart';
import '../../app/l10n_ext.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/entities.dart';
import '../../data/models/item_colors.dart';
import 'add_item_page.dart';
import 'item_detail_page.dart';

class CategoryItemsPage extends ConsumerStatefulWidget {
  const CategoryItemsPage({super.key, required this.category});

  final CategoryEntity category;

  @override
  ConsumerState<CategoryItemsPage> createState() => _CategoryItemsPageState();
}

class _CategoryItemsPageState extends ConsumerState<CategoryItemsPage> {
  String _keyword = '';
  List<ItemEntity> _items = [];
  bool _loading = true;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = await ref.read(itemRepoProvider.future);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final colorKeys = matchColorKeys(_keyword, l10n);
    setState(() {
      _items = repo.listByCategory(
        widget.category.id,
        keyword: _keyword,
        colorKeys: colorKeys.isEmpty ? null : colorKeys,
      );
      _loading = false;
    });
  }

  Future<void> _addItem() async {
    final changed = await openAddItemFlow(context, ref, initialCategory: widget.category);
    if (changed == true) {
      _dirty = true;
      await _load();
    }
  }

  Future<void> _deleteItem(ItemEntity item) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteItem),
        content: Text(l10n.deleteItemConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;

    final repo = await ref.read(itemRepoProvider.future);
    await repo.delete(item);
    _dirty = true;
    await _load();
  }

  Future<void> _openDetail(ItemEntity item) async {
    final catRepo = await ref.read(categoryRepoProvider.future);
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemDetailPage(
          item: item,
          categoryName: catRepo.pathLabel(widget.category),
        ),
      ),
    );
    if (changed == true) {
      _dirty = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categoryName = widget.category.name;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_dirty);
      },
      child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: translucentAppBar(context),
          title: Text(categoryName),
          leading: BackButton(onPressed: () => Navigator.of(context).pop(_dirty)),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                onSubmitted: (v) {
                  _keyword = v.trim();
                  _load();
                },
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.5,
                                child: Center(
                                  child: Text(
                                    l10n.noItemsHint,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            physics: const AlwaysScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return _ItemTile(
                                item: item,
                                l10n: l10n,
                                onTap: () => _openDetail(item),
                                onDelete: () => _deleteItem(item),
                                onRetry: item.syncStatus == SyncStatus.failed
                                    ? () async {
                                        final repo = await ref.read(itemRepoProvider.future);
                                        await repo.retrySync(item);
                                        await _load();
                                      }
                                    : null,
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addItem,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.l10n,
    required this.onTap,
    required this.onDelete,
    this.onRetry,
  });

  final ItemEntity item;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: translucentSurface(context),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.localImagePath.isNotEmpty && File(item.localImagePath).existsSync())
                    Image.file(File(item.localImagePath), fit: BoxFit.cover)
                  else
                    Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: SyncStatusBadge(status: item.syncStatus),
                  ),
                  if (item.colors.isNotEmpty)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Row(
                        children: item.colors.take(3).map((k) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: CircleAvatar(radius: 8, backgroundColor: itemColorValue(k)),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title.isEmpty ? l10n.unnamed : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (onRetry != null)
                    IconButton(
                      icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                      onPressed: onRetry,
                      tooltip: l10n.retrySync,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
