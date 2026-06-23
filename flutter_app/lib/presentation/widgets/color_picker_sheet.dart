import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../data/models/item_colors.dart';
import '../../app/l10n_ext.dart';

/// 多选颜色底部面板
Future<List<String>?> showColorPickerSheet({
  required BuildContext context,
  required List<String> initialSelected,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ColorPickerSheet(initialSelected: List.from(initialSelected)),
  );
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initialSelected});

  final List<String> initialSelected;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
  }

  void _toggle(String key) {
    setState(() {
      if (_selected.contains(key)) {
        _selected.remove(key);
      } else {
        _selected.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(l10n.colorLabel, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(onPressed: () => setState(() => _selected.clear()), child: Text(l10n.clearAll)),
                TextButton(onPressed: () => Navigator.pop(context, _selected), child: Text(l10n.confirm)),
              ],
            ),
            if (_selected.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.selectedColors, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ..._selected.map(
                        (k) => CircleAvatar(
                          radius: 12,
                          backgroundColor: itemColorValue(k),
                          child: k == 'white'
                              ? Icon(Icons.check, size: 14, color: Colors.grey[700])
                              : const Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxH - 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: itemColorOptions.length,
                itemBuilder: (context, index) {
                  final opt = itemColorOptions[index];
                  final checked = _selected.contains(opt.key);
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: opt.color, radius: 16),
                    title: Text(itemColorLabel(l10n, opt.key)),
                    trailing: checked ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                    onTap: () => _toggle(opt.key),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 添加/编辑页内嵌颜色选择行
class ColorSelectorField extends StatelessWidget {
  const ColorSelectorField({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () async {
        final result = await showColorPickerSheet(context: context, initialSelected: selected);
        if (result != null) onChanged(result);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.colorLabel,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.palette_outlined),
        ),
        child: selected.isEmpty
            ? Text(l10n.colorHint, style: TextStyle(color: Colors.grey[600]))
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                children: selected
                    .map(
                      (k) => Chip(
                        avatar: CircleAvatar(backgroundColor: itemColorValue(k), radius: 8),
                        label: Text(itemColorLabel(l10n, k), style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
      ),
    );
  }
}
