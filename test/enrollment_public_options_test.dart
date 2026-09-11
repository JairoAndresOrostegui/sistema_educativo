import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/modules/enrollment/controllers/enrollment_form_controller.dart';
import 'package:sistema_educativo/modules/enrollment/services/enrollment_service.dart';
import 'package:sistema_educativo/utils/parameters_service.dart';

class _NoPrivateFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'La matrícula pública no debe consultar Firestore privado.',
  );
}

class _UnusedParameters implements ParametersService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('La matrícula pública no debe leer catálogos privados.');
}

class _UnusedEnrollment implements EnrollmentService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EnrollmentFormController _controller(
  Future<Map<String, dynamic>> Function() load,
) =>
    EnrollmentFormController(
        params: _UnusedParameters(),
        enrollmentService: _UnusedEnrollment(),
        firestore: _NoPrivateFirestore(),
        publicOptionsLoader: load,
      )
      ..initControllers()
      ..initDefaults();

void main() {
  test(
    'matrícula pública carga proyección y usa año vigente de cada sede',
    () async {
      final controller = _controller(
        () async => {
          'institutions': [
            {
              'id': 'i',
              'label': 'Colegio',
              'campuses': ['a', 'b'],
            },
          ],
          'groups': [
            for (final campus in ['a', 'b'])
              {
                'id': 'group-$campus',
                'institutionId': 'i',
                'campusId': campus,
                'academicYear': campus == 'a' ? 2031 : 2032,
                'name': 'Cuarto A',
                'level': 'Cuarto',
                'active': true,
              },
          ],
          'documentTypes': [
            {'valor': 'TI', 'etiqueta': 'Tarjeta de identidad'},
          ],
          'eps': [
            {'valor': 'EPS001', 'etiqueta': 'EPS de prueba'},
          ],
        },
      );
      addTearDown(controller.dispose);
      expect(controller.anioMatricula, isNull);
      await controller.loadOptions(publicMode: true);
      expect(controller.optionsError, isNull);
      expect(controller.anioMatricula, 2031);
      expect(controller.tiposDocumento, ['TI']);
      expect(controller.eps, ['EPS001']);
      controller.selectCampus('b');
      expect(controller.anioMatricula, 2032);
    },
  );

  test(
    'error de opciones no inventa EPS ni año y permite reintentar',
    () async {
      final controller = _controller(
        () async => throw StateError('Servicio no disponible.'),
      );
      addTearDown(controller.dispose);
      await controller.loadOptions(publicMode: true);
      expect(controller.loadingOptions, isFalse);
      expect(controller.optionsError, 'Servicio no disponible.');
      expect(controller.eps, isEmpty);
      expect(controller.tiposDocumento, isEmpty);
      expect(controller.anioMatricula, isNull);
    },
  );

  test('salir durante la carga no escribe ni notifica tras dispose', () async {
    final response = Completer<Map<String, dynamic>>();
    final controller = _controller(() => response.future);
    var changes = 0;
    controller.addListener(() => changes++);
    final load = controller.loadOptions(publicMode: true);
    expect(changes, 1);
    controller.dispose();
    response.complete({
      'institutions': [
        {
          'id': 'i',
          'label': 'Colegio',
          'campuses': ['a'],
        },
      ],
      'groups': [
        {
          'id': 'group-a',
          'institutionId': 'i',
          'campusId': 'a',
          'academicYear': 2031,
          'name': 'Cuarto A',
          'level': 'Cuarto',
          'active': true,
        },
      ],
    });
    await expectLater(load, completes);
    expect(changes, 1);
    expect(controller.academicGroups, isEmpty);
    expect(controller.anioMatricula, isNull);
  });
}
