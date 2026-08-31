import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/enrollment/screens/widgets/enrollment_document_search_card.dart';
import 'package:sistema_educativo/modules/enrollment/screens/widgets/enrollment_form_actions.dart';
import 'package:sistema_educativo/modules/enrollment/screens/widgets/enrollment_grade_history_section.dart';
import 'package:sistema_educativo/modules/enrollment/screens/widgets/enrollment_scope_selector.dart';
import 'package:sistema_educativo/modules/schedule/widgets/subject_form_dialog.dart';
import 'package:sistema_educativo/utils/parameters_service.dart';

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
                  'groupName': 'Cuarto A',
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

  testWidgets('enrollment scope selectors fit and update on mobile', (
    tester,
  ) async {
    await useMobileViewport(tester);
    String? institution;
    String? campus;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: EnrollmentScopeSelector(
              institutions: const [
                InstitutionOption(
                  id: 'llinas',
                  label: 'Institución Educativa Rodolfo Llinás',
                  campuses: ['Piedecuesta', 'Barrancabermeja'],
                ),
              ],
              campuses: const ['Piedecuesta', 'Barrancabermeja'],
              institutionId: 'llinas',
              campusId: 'Piedecuesta',
              onInstitutionChanged: (value) => institution = value,
              onCampusChanged: (value) => campus = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Piedecuesta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barrancabermeja').last);
    await tester.pumpAndSettle();

    expect(institution, isNull);
    expect(campus, 'Barrancabermeja');
    expect(tester.takeException(), isNull);
  });

  testWidgets('family correction action is explicit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnrollmentFormActions(
            isAdmin: false,
            disabled: false,
            currentEstado: 'correccion_solicitada',
            onGuardarRevision: () {},
            onMatricular: () {},
          ),
        ),
      ),
    );

    expect(find.text('Enviar correcciones'), findsOneWidget);
    expect(find.text('Guardar solicitud'), findsNothing);
  });

  testWidgets('schedule form fits a 320 pixel viewport', (tester) async {
    await useMobileViewport(tester);
    final teacher = userModelv2(
      id: 'teacher',
      firstName: 'María',
      lastName: 'Docente con nombre extenso',
      document: '1',
      documentType: 'CC',
      personalEmail: '',
      institutionalEmail: 'teacher@school.test',
      role: 'Docente',
      institution: 'inst-1',
      campus: 'campus-1',
      isSuperadmin: false,
      status: 'activo',
      phones: const [],
      permissions: const ['horarios.ver'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => SubjectFormDialog(
                  teachers: [teacher],
                  daysOfWeek: const ['lunes'],
                  onSave: (_) async {},
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Crear materia'), findsOneWidget);
    expect(find.text('Hora de inicio'), findsOneWidget);
    expect(find.text('Hora de fin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
