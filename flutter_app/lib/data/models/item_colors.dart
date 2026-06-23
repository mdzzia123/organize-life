import 'package:flutter/material.dart';

class ItemColorOption {
  const ItemColorOption(this.key, this.color);
  final String key;
  final Color color;
}

/// 预设颜色系（key 用于存储与云端同步）
const itemColorOptions = [
  ItemColorOption('black', Color(0xFF212121)),
  ItemColorOption('white', Color(0xFFF5F5F5)),
  ItemColorOption('grey', Color(0xFF9E9E9E)),
  ItemColorOption('nude', Color(0xFFE8C4A8)),
  ItemColorOption('gold', Color(0xFFD4AF37)),
  ItemColorOption('silver', Color(0xFFC0C0C0)),
  ItemColorOption('red', Color(0xFFE53935)),
  ItemColorOption('pink', Color(0xFFEC407A)),
  ItemColorOption('orange', Color(0xFFFB8C00)),
  ItemColorOption('yellow', Color(0xFFFDD835)),
  ItemColorOption('green', Color(0xFF43A047)),
  ItemColorOption('blue', Color(0xFF1E88E5)),
  ItemColorOption('purple', Color(0xFF8E24AA)),
  ItemColorOption('brown', Color(0xFF6D4C41)),
];

ItemColorOption? itemColorByKey(String key) {
  for (final o in itemColorOptions) {
    if (o.key == key) return o;
  }
  return null;
}

Color itemColorValue(String key) => itemColorByKey(key)?.color ?? Colors.grey;
