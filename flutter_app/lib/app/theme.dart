import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../data/models/entities.dart';
import 'l10n_ext.dart';

class AppTheme {
  static const _seed = Color(0xFF4A6CF7);

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 2,
      ),
    );
  }
}

Color parseHexColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

IconData categoryIcon(String name) {
  switch (name) {
    case 'checkroom':
      return Icons.checkroom_outlined;
    case 'face':
      return Icons.face_outlined;
    case 'medical_services':
      return Icons.medical_services_outlined;
    case 'badge':
      return Icons.badge_outlined;
    case 'kitchen':
      return Icons.kitchen_outlined;
    case 'chair':
      return Icons.chair_outlined;
    case 'diamond':
      return Icons.diamond_outlined;
    case 'collections':
      return Icons.collections_outlined;
    case 'devices':
      return Icons.devices_outlined;
    case 'account_balance':
      return Icons.account_balance_outlined;
    case 'subcategory':
      return Icons.folder_outlined;
    default:
      return Icons.category_outlined;
  }
}

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key, required this.status});
  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.synced) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final label = syncStatusLabel(l10n, status);
    if (label.isEmpty) return const SizedBox.shrink();
    final color = switch (status) {
      SyncStatus.pending => Colors.orange,
      SyncStatus.failed => Colors.red,
      SyncStatus.localOnly => Colors.grey,
      SyncStatus.synced => Colors.transparent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
