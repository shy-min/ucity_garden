import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ucityapp/screens/legal_screen.dart';
import 'package:ucityapp/theme.dart';

void main() {
  testWidgets('Privacy policy screen renders with support email', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const LegalScreen(page: LegalPage.privacy)));
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.textContaining(AppConfig.supportEmail), findsOneWidget);
  });

  testWidgets('Community guidelines screen renders', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const LegalScreen(page: LegalPage.terms)));
    expect(find.text('Community Guidelines'), findsOneWidget);
    expect(find.textContaining('zero tolerance'), findsOneWidget);
  });

  test('timeAgo formats recent times', () {
    expect(timeAgo(DateTime.now()), 'just now');
    expect(timeAgo(DateTime.now().subtract(const Duration(hours: 3))), '3h ago');
  });
}
