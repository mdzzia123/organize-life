import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_background.dart';
import '../../app/locale_provider.dart';
import '../../app/theme_mode_provider.dart';
import '../../app/providers.dart';
import '../../data/services/cloud_config.dart';
import '../widgets/simple_color_picker_dialog.dart';
import 'auth_page.dart';
import 'membership_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String? _deviceId;
  String? _pingResult;
  bool _testing = false;
  bool _syncing = false;
  bool _pulling = false;
  String? _accountEmail;
  bool _loggedIn = false;
  bool _isMember = false;
  Map<String, int>? _syncStats;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    _loadSyncStats();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final cloud = ref.read(cloudApiProvider);
    await cloud.init();
    if (mounted) {
      setState(() {
        _loggedIn = cloud.session.isLoggedIn;
        _accountEmail = cloud.session.email;
        _isMember = cloud.session.isMember;
      });
    }
    if (cloud.session.isLoggedIn) {
      try {
        final profile = await cloud.getAccountProfile();
        if (mounted) {
          setState(() {
            _loggedIn = profile['isLoggedIn'] == true;
            _accountEmail = profile['email']?.toString();
            _isMember = (profile['member'] as Map?)?['isMember'] == true || cloud.session.isMember;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadSyncStats() async {
    final repo = await ref.read(itemRepoProvider.future);
    if (mounted) setState(() => _syncStats = repo.syncStats());
  }

  Future<void> _loadDeviceId() async {
    final id = await ref.read(cloudApiProvider).getDeviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  Future<void> _testCloud() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _testing = true;
      _pingResult = null;
    });
    try {
      final cloud = ref.read(cloudApiProvider);
      await cloud.registerDevice();
      final res = await cloud.ping();
      Map<String, dynamic>? cfg;
      try {
        cfg = await cloud.getServiceConfig();
      } catch (_) {}
      if (mounted) {
        final emailDbg = cfg?['email']?['debug'] == true ? ' · email debug' : '';
        final payDbg = cfg?['pay']?['debug'] == true ? ' · pay debug' : '';
        setState(() => _pingResult = '${l10n.cloudOk(res['time']?.toString() ?? '')}$emailDbg$payDbg');
      }
    } catch (e) {
      if (mounted) setState(() => _pingResult = l10n.cloudFail(e.toString()));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _pullFromCloud() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_loggedIn || !_isMember) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.memberPullNeedUpgrade)));
      return;
    }
    setState(() => _pulling = true);

    try {
      final sync = await ref.read(cloudSyncProvider.future);
      final result = await sync.pullFromCloud();

      await _loadSyncStats();
      if (!mounted) return;

      final errMsg = result.errors.isEmpty ? '' : ' · ${result.errors.length}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pullDone(
              result.itemsDownloaded,
              result.itemsUpdated,
              result.itemsSkipped,
              errMsg,
            ),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.pullFail(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  Future<void> _retryAllSync() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _syncing = true);
    try {
      final repo = await ref.read(itemRepoProvider.future);
      final need = repo.listNeedSync().length;
      if (need == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noPendingSync)));
        }
        return;
      }
      final ok = await repo.retryAllFailed();
      await _loadSyncStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.retryDone(need, ok))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.syncFail(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _pickLanguage() async {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(localeProvider);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.language, style: Theme.of(ctx).textTheme.titleMedium)),
            _langTile(ctx, 'system', l10n.languageFollowSystem, current == null),
            _langTile(ctx, 'zh', l10n.langZh, current?.languageCode == 'zh'),
            _langTile(ctx, 'en', l10n.langEn, current?.languageCode == 'en'),
            _langTile(ctx, 'ja', l10n.langJa, current?.languageCode == 'ja'),
            _langTile(ctx, 'fr', l10n.langFr, current?.languageCode == 'fr'),
            _langTile(ctx, 'de', l10n.langDe, current?.languageCode == 'de'),
            _langTile(ctx, 'es', l10n.langEs, current?.languageCode == 'es'),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(localeProvider.notifier).setLanguageCode(selected);
    }
  }

  Widget _langTile(BuildContext ctx, String code, String label, bool selected) {
    return ListTile(
      title: Text(label),
      trailing: selected ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
      onTap: () => Navigator.pop(ctx, code),
    );
  }

  String _currentLanguageLabel(AppLocalizations l10n) {
    final locale = ref.watch(localeProvider);
    if (locale == null) return l10n.languageFollowSystem;
    switch (locale.languageCode) {
      case 'zh':
        return l10n.langZh;
      case 'en':
        return l10n.langEn;
      case 'ja':
        return l10n.langJa;
      case 'fr':
        return l10n.langFr;
      case 'de':
        return l10n.langDe;
      case 'es':
        return l10n.langEs;
      default:
        return l10n.langZh;
    }
  }

  Future<void> _pickAppearance() async {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(themeModeProvider);
    final selected = await showModalBottomSheet<AppThemePreference>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.appearance, style: Theme.of(ctx).textTheme.titleMedium)),
            _appearanceTile(ctx, AppThemePreference.system, l10n.themeFollowSystem, current == AppThemePreference.system),
            _appearanceTile(ctx, AppThemePreference.light, l10n.themeLight, current == AppThemePreference.light),
            _appearanceTile(ctx, AppThemePreference.dark, l10n.themeDark, current == AppThemePreference.dark),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(themeModeProvider.notifier).setPreference(selected);
    }
  }

  Widget _appearanceTile(BuildContext ctx, AppThemePreference mode, String label, bool selected) {
    return ListTile(
      title: Text(label),
      trailing: selected ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary) : null,
      onTap: () => Navigator.pop(ctx, mode),
    );
  }

  String _currentAppearanceLabel(AppLocalizations l10n) {
    return switch (ref.watch(themeModeProvider)) {
      AppThemePreference.system => l10n.themeFollowSystem,
      AppThemePreference.light => l10n.themeLight,
      AppThemePreference.dark => l10n.themeDark,
    };
  }

  Future<void> _pickBackground(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.background, style: Theme.of(ctx).textTheme.titleMedium)),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.pickBgColor),
              onTap: () async {
                Navigator.pop(ctx);
                final color = await showDialog<Color>(
                  context: context,
                  builder: (cctx) => SimpleColorPickerDialog(
                    initial: parseBgColor(ref.read(appBackgroundProvider).solidColor),
                  ),
                );
                if (color != null) await ref.read(appBackgroundProvider.notifier).setSolidColor(color);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.takeBgPhoto),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(appBackgroundProvider.notifier).pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.pickBgImage),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(appBackgroundProvider.notifier).pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: Text(l10n.resetBackground),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(appBackgroundProvider.notifier).resetDefault();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.appTitle),
            subtitle: Text(l10n.appVersionDesc),
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.language),
            subtitle: Text(_currentLanguageLabel(l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickLanguage,
          ),
          ListTile(
            title: Text(l10n.appearance),
            subtitle: Text(_currentAppearanceLabel(l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickAppearance,
          ),
          ListTile(
            title: Text(l10n.background),
            subtitle: Text(
              ref.watch(appBackgroundProvider).type == AppBackgroundType.image
                  ? l10n.backgroundImage
                  : l10n.backgroundSolid,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickBackground(context),
          ),
          ListTile(
            title: Text(l10n.membership),
            subtitle: Text(_isMember ? l10n.memberActive : l10n.memberNotMember),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const MembershipPage()));
              await _loadAccount();
            },
          ),
          ListTile(
            title: Text(l10n.account),
            subtitle: Text(_loggedIn ? (_accountEmail ?? l10n.loggedIn) : l10n.accountNotLoggedIn),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              );
              if (changed == true) await _loadAccount();
            },
          ),
          ListTile(
            title: Text(l10n.cloudApiUrl),
            subtitle: Text(CloudConfig.apiBaseUrl, style: const TextStyle(fontSize: 12)),
          ),
          ListTile(
            title: Text(l10n.deviceId),
            subtitle: Text(_deviceId ?? '...', style: const TextStyle(fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _testing ? null : _testCloud,
              icon: _testing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_done_outlined),
              label: Text(l10n.testCloud),
            ),
          ),
          if (_pingResult != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_pingResult!, style: TextStyle(color: Colors.grey[700])),
            ),
          const SizedBox(height: 16),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l10n.dataSync, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _pulling ? null : _pullFromCloud,
              icon: _pulling
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_download_outlined),
              label: Text(_pulling ? l10n.pullingFromCloud : l10n.pullFromCloud),
            ),
          ),
          if (_syncStats != null)
            ListTile(
              title: Text(l10n.syncStatusTitle),
              subtitle: Text(
                l10n.syncStatusDetail(
                  _syncStats!['total'] ?? 0,
                  _syncStats!['synced'] ?? 0,
                  _syncStats!['failed'] ?? 0,
                  _syncStats!['pending'] ?? 0,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: _syncing ? null : _retryAllSync,
              icon: _syncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_outlined),
              label: Text(l10n.retryAllSync),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          ListTile(
            title: Text(l10n.dataStorage),
            subtitle: Text(l10n.dataStorageDesc),
          ),
        ],
      ),
    );
  }
}
