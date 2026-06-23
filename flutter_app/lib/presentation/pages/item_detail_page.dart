import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/l10n_ext.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../data/models/entities.dart';
import '../widgets/category_tree/category_editor.dart';
import '../widgets/category_tree/category_expandable_tree.dart';
import '../widgets/color_picker_sheet.dart';
import '../widgets/upload_progress_dialog.dart';
import 'manage_categories_page.dart';

class ItemDetailPage extends ConsumerStatefulWidget {
  const ItemDetailPage({super.key, required this.item, this.categoryName});

  final ItemEntity item;
  final String? categoryName;

  @override
  ConsumerState<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends ConsumerState<ItemDetailPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  final _pickerKey = GlobalKey<CategoryPickerSectionState>();
  late List<String> _selectedColors;
  int? _selectedCategoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.item.title);
    _noteCtrl = TextEditingController(text: widget.item.note);
    _selectedColors = List.from(widget.item.colors);
    _selectedCategoryId = widget.item.categoryLocalId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.categoryRequired)));
      return;
    }

    final catRepo = await ref.read(categoryRepoProvider.future);
    final cat = catRepo.findById(_selectedCategoryId!);
    if (cat == null) return;

    setState(() => _saving = true);
    try {
      final repo = await ref.read(itemRepoProvider.future);
      if (!mounted) return;
      widget.item
        ..title = _titleCtrl.text.trim()
        ..note = _noteCtrl.text.trim()
        ..colors = _selectedColors
        ..categoryLocalId = cat.id
        ..categoryCloudId = cat.cloudId;
      await showUploadProgress<ItemEntity>(
        context: context,
        task: (report) => repo.saveLocal(item: widget.item, onProgress: report),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(savedStatusMessage(l10n, widget.item.syncStatus))),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retrySync() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      final repo = await ref.read(itemRepoProvider.future);
      await showUploadProgress<void>(
        context: context,
        task: (report) => repo.retrySync(widget.item, onProgress: report),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.item.syncStatus == SyncStatus.synced ? l10n.syncSuccess : l10n.syncFailedMsg,
            ),
          ),
        );
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
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
    if (ok != true || !mounted) return;

    final repo = await ref.read(itemRepoProvider.future);
    await repo.delete(widget.item);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = widget.item;
    final hasImage = item.localImagePath.isNotEmpty && File(item.localImagePath).existsSync();
    final catRepoAsync = ref.watch(categoryRepoProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        title: Text(widget.categoryName ?? l10n.addItem),
        actions: [
          if (item.syncStatus == SyncStatus.failed)
            IconButton(onPressed: _saving ? null : _retrySync, icon: const Icon(Icons.cloud_upload_outlined)),
          IconButton(onPressed: _saving ? null : _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: catRepoAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.initFailed(e.toString()))),
        data: (catRepo) {
          final editor = CategoryEditor(ref);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(item.localImagePath), fit: BoxFit.contain),
                )
              else
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.image_not_supported, size: 48),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SyncStatusBadge(status: item.syncStatus),
                  const SizedBox(width: 8),
                  Text(
                    item.createdAt.toString().substring(0, 16),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(labelText: l10n.titleLabel, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(labelText: l10n.noteLabel, border: const OutlineInputBorder()),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              ColorSelectorField(
                selected: _selectedColors,
                onChanged: (v) => setState(() => _selectedColors = v),
              ),
              const SizedBox(height: 16),
              CategoryPickerSection(
                key: _pickerKey,
                catRepo: catRepo,
                selectedCategoryId: _selectedCategoryId,
                onSelected: (cat) => setState(() => _selectedCategoryId = cat?.id),
                onOpenManage: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCategoriesPage()));
                  _pickerKey.currentState?.refreshTree();
                },
                onAddCategory: () async {
                  final created = await editor.addRoot(context);
                  if (created != null) setState(() => _selectedCategoryId = created.id);
                  _pickerKey.currentState?.refreshTree();
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }
}
