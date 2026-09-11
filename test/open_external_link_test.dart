import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/utils/open_external_link.dart';

void main() {
  for (final throwsError in [false, true]) {
    testWidgets(
      'enlace externo controla fallo ${throwsError ? "SDK" : "sin app"}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => openExternalLink(
                    context,
                    Uri.parse('https://example.org'),
                    launcher: (_) async {
                      if (throwsError) throw StateError('platform unavailable');
                      return false;
                    },
                  ),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('No se pudo abrir el enlace.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
