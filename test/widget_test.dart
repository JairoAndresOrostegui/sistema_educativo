import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/app.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';


void main() {
  testWidgets('AppRouter renders with required provider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => UserProviderV2(),
        child: const AppRouter(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
