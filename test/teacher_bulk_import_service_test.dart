import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/user/services/teacher_bulk_import_service.dart';

void main() {
  userModelv2 admin() => userModelv2(
    id: 'admin-1',
    firstName: 'Admin',
    lastName: 'Local',
    document: '10000001',
    documentType: 'CC',
    personalEmail: 'admin@correo.test',
    institutionalEmail: 'admin@colegio.test',
    role: 'Administrador',
    institution: 'inst-1',
    campus: 'campus-1',
    isSuperadmin: false,
    status: 'activo',
    phones: const [],
    permissions: const ['usuarios.crear'],
  );

  Uint8List workbook(List<List<String>> rows) {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    for (final row in rows) {
      sheet.appendRow(row.map(TextCellValue.new).toList());
    }
    return Uint8List.fromList(excel.encode()!);
  }

  TeacherBulkImportService service(List<userModelv2> created) {
    return TeacherBulkImportService(
      documentTypeLoader: () async => {'cc': 'CC'},
      uniquenessCheck:
          ({
            required String personalEmail,
            required String institutionalEmail,
            required String document,
          }) async => null,
      createTeacher: (user) async => created.add(user),
    );
  }

  test(
    'importa docentes exclusivamente en la sede del administrador',
    () async {
      final created = <userModelv2>[];
      final result = await service(created).importTeachersFromBytes(
        bytes: workbook([
          ['nombres', 'apellidos', 'documento', 'correo', 'grupo'],
          ['Ana Maria', 'Perez Gomez', '12345678', 'ana@test.com', '5A'],
        ]),
        usuarioLogueado: admin(),
      );

      expect(result.createdCount, 1);
      expect(result.failures, isEmpty);
      expect(created.single.role, 'Docente');
      expect(created.single.institution, 'inst-1');
      expect(created.single.campus, 'campus-1');
      expect(created.single.status, 'activo');
    },
  );

  test('reporta duplicados internos sin crear la segunda fila', () async {
    final created = <userModelv2>[];
    final result = await service(created).importTeachersFromBytes(
      bytes: workbook([
        ['nombres', 'apellidos', 'documento', 'correo', 'grupo'],
        ['Ana', 'Perez', '12345678', 'ana@test.com', '5A'],
        ['Ana Dos', 'Perez', '12345678', 'ana2@test.com', '5B'],
      ]),
      usuarioLogueado: admin(),
    );

    expect(result.totalRows, 2);
    expect(result.createdCount, 1);
    expect(result.failedCount, 1);
    expect(result.failures.single.reason, contains('Documento duplicado'));
  });

  test('rechaza filas que intentan importar un rol diferente', () async {
    final created = <userModelv2>[];
    final result = await service(created).importTeachersFromBytes(
      bytes: workbook([
        ['nombres', 'apellidos', 'documento', 'correo', 'grupo', 'rol'],
        ['Ana', 'Perez', '12345678', 'ana@test.com', '5A', 'Administrador'],
      ]),
      usuarioLogueado: admin(),
    );

    expect(result.createdCount, 0);
    expect(result.failedCount, 1);
    expect(result.failures.single.reason, contains('solo crea'));
  });
}
