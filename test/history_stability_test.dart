import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/modules/history/services/history_query_utils.dart';
import 'package:sistema_educativo/modules/history/widgets/history_date_range_field.dart';
import 'package:sistema_educativo/modules/history/services/file_history_service.dart';
import 'package:sistema_educativo/models/academic/academic_group.dart';
import 'package:sistema_educativo/utils/academic_group_service.dart';

class _Firestore extends Fake implements FirebaseFirestore {}

class _AdminGroups extends Fake implements AcademicGroupService {
  String? institution;
  String? campus;
  @override
  Future<List<AcademicGroup>> listForAdministration({
    required String institutionId,
    required String campusId,
  }) async {
    institution = institutionId;
    campus = campusId;
    return [];
  }
}

void main() {
  test(
    'filtro historial consulta grupos administrativos por backend',
    () async {
      final groups = _AdminGroups();
      final service = DocumentHistoryService(db: _Firestore(), groups: groups);
      expect(
        await service.obtenerGrupos(
          institutionId: 'institution-1',
          campusId: 'campus-2',
        ),
        isEmpty,
      );
      expect(groups.institution, 'institution-1');
      expect(groups.campus, 'campus-2');
    },
  );
  test('historial normaliza fechas válidas y tolera datos dañados', () {
    final date = DateTime(2026, 9, 11, 8, 30);
    expect(historyDate(Timestamp.fromDate(date)), date);
    expect(historyDate(date), date);
    expect(historyDate(date.millisecondsSinceEpoch), date);
    expect(historyDate('fecha-invalida'), isNull);
    expect(historyDate(-1), isNull);
    expect(historyDate(null), isNull);
  });

  testWidgets('selector de rango es accesible y no crea un campo editable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryDateRangeField(
            value: '2026-09-01 → 2026-09-11',
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('2026-09-01 → 2026-09-11'), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    expect(taps, 1);
  });
}
