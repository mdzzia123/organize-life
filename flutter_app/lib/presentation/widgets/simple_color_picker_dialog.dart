import 'package:flutter/material.dart';

import '../../app/app_background.dart';

/// 简易纯色选择器
class SimpleColorPickerDialog extends StatelessWidget {
  const SimpleColorPickerDialog({super.key, required this.initial});

  final Color initial;

  static const _swatches = [
    '#F5F6FA', '#FFFFFF', '#E8F5E9', '#E3F2FD', '#FFF3E0', '#FCE4EC',
    '#212121', '#455A64', '#5B8DEF', '#E87BA0', '#4CAF88', '#FF7043',
    '#8D6E63', '#AB47BC', '#2196F3', '#795548',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _swatches.map((hex) {
          final c = parseBgColor(hex);
          final selected = c.value == initial.value;
          return InkWell(
            onTap: () => Navigator.pop(context, c),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.blue : Colors.grey.shade400,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
