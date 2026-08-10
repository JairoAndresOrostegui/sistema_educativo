import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/modules/enrollment/screens/widgets/enrollment_document_search_card.dart';
import 'package:sistema_educativo/modules/enrollment/screens/widgets/enrollment_grade_history_section.dart';

void main() {
  Future<void> useMobileViewport(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
  }

  testWidgets('enrollment search wraps its actions on a narrow screen', (
    tester,
  ) async {
    await useMobileViewport(tester);
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EnrollmentDocumentSearchCard(
              controller: controller,
              onSearch: () {},
              loading: false,
              selectedDocument: '1234567890',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Buscar y prellenar'), findsOneWidget);
    expect(find.textContaining('Documento seleccionado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grade history becomes readable cards on mobile', (tester) async {
    await useMobileViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: EnrollmentGradeHistorySection(
              label: 'Historial académico',
              entries: const [
                {
                  'anio': 2025,
                  'institucion': 'Institución con un nombre bastante largo',
                  'grado': 'Cuarto A',
                  'interno': false,
                },
              ],
              readOnly: false,
              onAdd: () {},
              onRemove: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Institución con un nombre'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
