import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../data/models/entities.dart';
import '../../data/models/item_colors.dart';

export '../../data/models/category_entity_l10n.dart';

String itemColorLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'black':
      return l10n.colorBlack;
    case 'white':
      return l10n.colorWhite;
    case 'grey':
      return l10n.colorGrey;
    case 'nude':
      return l10n.colorNude;
    case 'gold':
      return l10n.colorGold;
    case 'silver':
      return l10n.colorSilver;
    case 'red':
      return l10n.colorRed;
    case 'pink':
      return l10n.colorPink;
    case 'orange':
      return l10n.colorOrange;
    case 'yellow':
      return l10n.colorYellow;
    case 'green':
      return l10n.colorGreen;
    case 'blue':
      return l10n.colorBlue;
    case 'purple':
      return l10n.colorPurple;
    case 'brown':
      return l10n.colorBrown;
    default:
      return key;
  }
}

String syncStatusLabel(AppLocalizations l10n, SyncStatus status) {
  switch (status) {
    case SyncStatus.pending:
      return l10n.syncPending;
    case SyncStatus.failed:
      return l10n.syncFailedBadge;
    case SyncStatus.localOnly:
      return l10n.syncLocalOnly;
    case SyncStatus.synced:
      return '';
  }
}

String savedStatusMessage(AppLocalizations l10n, SyncStatus status) {
  switch (status) {
    case SyncStatus.synced:
      return l10n.savedAndSynced;
    case SyncStatus.failed:
      return l10n.savedFailed;
    case SyncStatus.pending:
      return l10n.savedPending;
    case SyncStatus.localOnly:
      return l10n.savedPending;
  }
}

/// 根据关键词匹配颜色 key（支持本地化标签）
Set<String> matchColorKeys(String keyword, AppLocalizations l10n) {
  final kw = keyword.trim().toLowerCase();
  if (kw.isEmpty) return {};
  final keys = <String>{};
  for (final opt in itemColorOptions) {
    final label = itemColorLabel(l10n, opt.key).toLowerCase();
    if (opt.key.contains(kw) || label.contains(kw)) keys.add(opt.key);
  }
  return keys;
}
