import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppBackgroundType { theme, solid, image }

class AppBackgroundSettings {
  const AppBackgroundSettings({
    this.type = AppBackgroundType.theme,
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
    final typeStr = prefs.getString(_typeKey);
    final savedColor = prefs.getString(_colorKey) ?? '';
    final imagePath = prefs.getString(_imageKey) ?? '';

    AppBackgroundType type;
    if (typeStr == 'image') {
      type = AppBackgroundType.image;
    } else if (typeStr == 'solid' && savedColor.isNotEmpty && savedColor.toUpperCase() != '#F5F6FA') {
      type = AppBackgroundType.solid;
    } else if (typeStr == 'solid') {
      // 旧版默认浅灰背景 → 迁移为跟随主题
      type = AppBackgroundType.theme;
    } else {
      type = AppBackgroundType.theme;
    }

    state = AppBackgroundSettings(
      type: type,
      solidColor: savedColor.isNotEmpty ? savedColor : '#F5F6FA',
      imagePath: imagePath,
    );
  }

  Future<void> setFollowTheme() async {
    state = const AppBackgroundSettings(type: AppBackgroundType.theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_typeKey, 'theme');
    await prefs.remove(_colorKey);
    await prefs.remove(_imageKey);
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
    await setFollowTheme();
  }
}

Color parseBgColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

/// 半透明 AppBar，随深浅色主题变化
Color translucentAppBar(BuildContext context) =>
    Theme.of(context).colorScheme.surface.withValues(alpha: 0.92);

/// 半透明卡片/列表项表面
Color translucentSurface(BuildContext context) =>
    Theme.of(context).colorScheme.surface.withValues(alpha: 0.94);

/// 全局背景层
class AppBackground extends ConsumerWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bg = ref.watch(appBackgroundProvider);
    final theme = Theme.of(context);

    Widget background;
    if (bg.type == AppBackgroundType.image &&
        bg.imagePath.isNotEmpty &&
        File(bg.imagePath).existsSync()) {
      background = DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(image: FileImage(File(bg.imagePath)), fit: BoxFit.cover),
        ),
        child: const SizedBox.expand(),
      );
    } else if (bg.type == AppBackgroundType.solid) {
      background = ColoredBox(color: parseBgColor(bg.solidColor));
    } else {
      background = ColoredBox(color: theme.scaffoldBackgroundColor);
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
