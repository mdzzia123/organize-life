import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppBackgroundType { solid, image }

class AppBackgroundSettings {
  const AppBackgroundSettings({
    this.type = AppBackgroundType.solid,
    this.solidColor = '#F5F6FA',
    this.imagePath = '',
  });

  final AppBackgroundType type;
  final String solidColor;
  final String imagePath;

  AppBackgroundSettings copyWith({
    AppBackgroundType? type,
    String? solidColor,
    String? imagePath,
  }) {
    return AppBackgroundSettings(
      type: type ?? this.type,
      solidColor: solidColor ?? this.solidColor,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

final appBackgroundProvider = StateNotifierProvider<AppBackgroundNotifier, AppBackgroundSettings>((ref) {
  return AppBackgroundNotifier();
});

class AppBackgroundNotifier extends StateNotifier<AppBackgroundSettings> {
  AppBackgroundNotifier() : super(const AppBackgroundSettings()) {
    _load();
  }

  static const _typeKey = 'ol_bg_type';
  static const _colorKey = 'ol_bg_color';
  static const _imageKey = 'ol_bg_image';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString(_typeKey) ?? 'solid';
    state = AppBackgroundSettings(
      type: typeStr == 'image' ? AppBackgroundType.image : AppBackgroundType.solid,
      solidColor: prefs.getString(_colorKey) ?? '#F5F6FA',
      imagePath: prefs.getString(_imageKey) ?? '',
    );
  }

  Future<void> setSolidColor(Color color) async {
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    state = state.copyWith(type: AppBackgroundType.solid, solidColor: hex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, 'solid');
    await prefs.setString(_colorKey, hex);
  }

  Future<void> setImageFromPath(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final bgDir = Directory(p.join(dir.path, 'backgrounds'));
    if (!await bgDir.exists()) await bgDir.create(recursive: true);
    final dest = p.join(bgDir.path, 'app_bg${p.extension(sourcePath)}');
    await File(sourcePath).copy(dest);
    state = state.copyWith(type: AppBackgroundType.image, imagePath: dest);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, 'image');
    await prefs.setString(_imageKey, dest);
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null) return;
    await setImageFromPath(picked.path);
  }

  Future<void> resetDefault() async {
    state = const AppBackgroundSettings();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_typeKey);
    await prefs.remove(_colorKey);
    await prefs.remove(_imageKey);
  }
}

Color parseBgColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

/// 全局背景层
class AppBackground extends ConsumerWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = ref.watch(appBackgroundProvider);
    Widget background;
    if (bg.type == AppBackgroundType.image && bg.imagePath.isNotEmpty && File(bg.imagePath).existsSync()) {
      background = DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(image: FileImage(File(bg.imagePath)), fit: BoxFit.cover),
        ),
        child: const SizedBox.expand(),
      );
    } else {
      background = ColoredBox(color: parseBgColor(bg.solidColor));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        child,
      ],
    );
  }
}
