import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/app_background.dart';
import '../../app/l10n_ext.dart';
import '../../app/providers.dart';
import '../../data/models/entities.dart';
import '../widgets/category_tree/category_editor.dart';
import '../widgets/category_tree/category_expandable_tree.dart';
import '../widgets/color_picker_sheet.dart';
import '../widgets/upload_progress_dialog.dart';
import 'manage_categories_page.dart';

/// 启动添加图片流程：选图 → 创建页
Future<bool?> openAddItemFlow(
  BuildContext context,
  WidgetRef ref, {
  CategoryEntity? initialCategory,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.takePhoto),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.pickFromGallery),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;

  final localPath = await _pickAndCopyImage(source);
  if (localPath == null || !context.mounted) return null;

  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => AddItemPage(
        localImagePath: localPath,
        initialCategory: initialCategory,
      ),
    ),
  );
}

Future<String?> _pickAndCopyImage(ImageSource source) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: source, imageQuality: 85);
  if (picked == null) return null;

  final dir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory(p.join(dir.path, 'images'));
  if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

  final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
  final dest = File(p.join(imagesDir.path, fileName));
  await File(picked.path).copy(dest.path);
  return dest.path;
}

class AddItemPage extends ConsumerStatefulWidget {
  const AddItemPage({
    super.key,
    required this.localImagePath,
    this.initialCategory,
  });

  final String localImagePath;
  final CategoryEntity? initialCategory;

  @override
  ConsumerState<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends ConsumerState<AddItemPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  final _pickerKey = GlobalKey<CategoryPickerSectionState>();
  int? _selectedCategoryId;
  List<String> _selectedColors = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _noteCtrl = TextEditingController();
    _selectedCategoryId = widget.initialCategory?.id;
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
      final item = ItemEntity()
        ..categoryLocalId = cat.id
        ..categoryCloudId = cat.cloudId
        ..localImagePath = widget.localImagePath
        ..title = _titleCtrl.text.trim()
        ..note = _noteCtrl.text.trim()
        ..colors = _selectedColors
        ..syncStatus = SyncStatus.pending;

      await showUploadProgress<ItemEntity>(
        context: context,
        task: (report) => repo.saveLocal(item: item, onProgress: report),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(savedStatusMessage(l10n, item.syncStatus))),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catRepoAsync = ref.watch(categoryRepoProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: translucentAppBar(context),
        title: Text(l10n.createItem),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.save),
            ),
          ),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(widget.localImagePath), height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(labelText: l10n.titleOptional, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(labelText: l10n.noteOptional, border: const OutlineInputBorder()),
                maxLines: 2,
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
                },
                onAddCategory: () async {
                  final created = await editor.addRoot(context);
                  if (created != null) setState(() => _selectedCategoryId = created.id);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
