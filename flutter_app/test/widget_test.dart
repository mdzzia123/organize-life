import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:organize_life/app/theme.dart';
import 'package:organize_life/presentation/pages/home_page.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OrganizeLifeApp()));
    expect(find.text('整理人生'), findsOneWidget);
  });
}

class OrganizeLifeApp extends StatelessWidget {
  const OrganizeLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '整理人生',
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}
