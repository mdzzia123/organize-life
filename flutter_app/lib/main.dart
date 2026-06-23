import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_background.dart';
import 'app/locale_provider.dart';
import 'app/theme.dart';
import 'app/theme_mode_provider.dart';
import 'data/services/payment_service.dart';
import 'presentation/pages/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PaymentService().initWechat();
  runApp(const ProviderScope(child: OrganizeLifeApp()));
}

class OrganizeLifeApp extends ConsumerWidget {
  const OrganizeLifeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themePref = ref.watch(themeModeProvider);
    final themeMode = switch (themePref) {
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
      AppThemePreference.system => ThemeMode.system,
    };

    return MaterialApp(
      title: '整理人生',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (device, supported) => resolveLocale(device, locale),
      builder: (context, child) => AppBackground(child: child ?? const SizedBox.shrink()),
      home: const HomePage(),
    );
  }
}
