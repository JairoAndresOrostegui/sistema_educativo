import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/events/models/event_models.dart';
import 'package:sistema_educativo/modules/events/screens/event_detail_screen.dart';
import 'package:sistema_educativo/modules/events/screens/events_screen.dart';
import 'package:sistema_educativo/modules/events/services/event_service.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';
import 'support/active_student_channel_stub.dart';

Map<String, dynamic> eventData({
  String type = 'student_presentation',
  bool draft = false,
  bool started = false,
}) => {
  'id': 'event',
  'title': 'Encuentro del colegio',
  'subtitle': 'Participación de los cursos',
  'eventType': type,
  'foodEnabled': type == 'student_presentation',
  'status': draft ? 'draft' : 'published',
  'description': 'Celebración de la sede',
  'location': 'Auditorio',
  'startAtMillis': DateTime.now()
      .add(Duration(days: started ? -1 : 1))
      .millisecondsSinceEpoch,
  'endAtMillis': DateTime.now()
      .add(const Duration(days: 2))
      .millisecondsSinceEpoch,
  'audienceType': 'groups',
  'targetGroupIds': ['group'],
  'targetStudentIds': [],
  'responsibleNames': {'teacher': 'Sara'},
  'revision': 3,
  'publicity': {'text': 'Invitación a nuestras familias', 'url': ''},
  'requirements': [
    {
      'id': 'kit',
      'label': 'Traer material',
      'targetType': 'student',
      'completionType': 'manual',
      'required': true,
    },
    {
      'id': 'meeting',
      'label': 'Asistencia familiar',
      'targetType': 'family',
      'completionType': 'attendance',
      'required': true,
    },
  ],
};

class Gateway implements EventGateway {
  Gateway({
    String type = 'student_presentation',
    bool draft = false,
    bool started = false,
    this.caps = const {},
    this.orders = const [],
    this.completions = const [],
  }) : event = eventData(type: type, draft: draft, started: started);
  Map<String, dynamic> event;
  final Map<String, bool> caps;
  final List<Map<String, dynamic>> orders, completions;
  final requests = <String, List<Map<String, dynamic>>>{};
  Future<EventDetail> Function(String?)? onDetail;
  Future<List<EventChild>> Function()? onChildren;
  Object? reserveError;
  final childrenList = const [
    EventChild(id: 'child-a', name: 'Ana'),
    EventChild(id: 'child-b', name: 'Bruno'),
  ];
  final food = <Map<String, dynamic>>[
    {
      'id': 'juice',
      'name': 'Jugo',
      'priceCop': 2500,
      'active': true,
      'revision': 1,
    },
  ];
  List<Map<String, dynamic>> get participants => [
    {
      'studentId': 'child-a',
      'studentName': 'Ana',
      'groupId': 'group',
      'families': [
        {'id': 'family', 'name': 'Madre Ana'},
        {'id': 'family-other', 'name': 'Padre Ana'},
      ],
    },
    {
      'studentId': 'child-b',
      'studentName': 'Bruno',
      'groupId': 'group',
      'families': [
        {'id': 'family', 'name': 'Madre Ana'},
      ],
    },
  ];
  EventDetail value({String? child}) => EventDetail.fromMap({
    'event': {...event, if (child != null) 'subtitle': 'Ficha de $child'},
    'capabilities': caps,
    'foodItems': food,
    'orders': orders,
    'completions': completions,
    'participants': caps['canManageFulfillment'] == true ? participants : [],
    'materials': [
      {
        'id': 'costume',
        'name': 'Traje blanco',
        'kind': 'costume',
        'instructions': 'Camisa blanca',
        'amountCop': 0,
        'address': 'Almacén del colegio',
        'groupIds': ['group'],
        'active': true,
      },
    ],
  });
  void record(String key, Map<String, dynamic> value) =>
      requests.putIfAbsent(key, () => []).add(value);
  @override
  Future<EventDetail> detail(String id, {String? studentId}) async {
    record('detail', {'eventId': id, 'studentId': studentId});
    return onDetail != null ? onDetail!(studentId) : value(child: studentId);
  }

  @override
  Future<List<EventChild>> children() async =>
      onChildren != null ? onChildren!() : childrenList;
  @override
  Future<List<SchoolEvent>> events({String? studentId}) async => [
    SchoolEvent.fromMap(event),
  ];
  @override
  Future<EventContext> contexts() async => EventContext(
    academicYear: DateTime.now().year,
    groups: const [EventGroup(id: 'group', name: 'Cuarto A')],
    responsibleUsers: const [
      EventResponsible(id: 'teacher', name: 'Sara', role: 'Docente'),
    ],
  );
  @override
  Future<String> saveDraft({
    String? eventId,
    int? expectedRevision,
    required Map<String, dynamic> value,
  }) async {
    record('draft', {
      'eventId': eventId,
      'expectedRevision': expectedRevision,
      ...value,
    });
    return 'event';
  }

  @override
  Future<Map<String, dynamic>> saveFood(Map<String, dynamic> value) async {
    record('food', value);
    return {};
  }

  @override
  Future<Map<String, dynamic>> saveMaterial(Map<String, dynamic> value) async {
    record('material', value);
    return {};
  }

  @override
  Future<Map<String, dynamic>> reserveFood(Map<String, dynamic> value) async {
    record('reserve', value);
    if (reserveError != null) throw reserveError!;
    return {};
  }

  @override
  Future<Map<String, dynamic>> manageOrder(Map<String, dynamic> value) async {
    record('order', value);
    return {};
  }

  @override
  Future<Map<String, dynamic>> saveCompletion(
    Map<String, dynamic> value,
  ) async {
    record('completion', value);
    return {};
  }

  @override
  Future<Map<String, dynamic>> prepareQr(Map<String, dynamic> value) async {
    record('qr', value);
    return {
      'eventId': 'event',
      'targetType': 'student',
      'targetId': 'child-a',
      'name': 'Ana',
      'students': [
        {'id': 'child-a', 'name': 'Ana'},
      ],
      'requirementIds': ['kit'],
      'credentialRevision': 1,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserProviderV2 provider(String role) => UserProviderV2()
  ..setUser(
    userModelv2.fromFirestore(
      {
        'role': role,
        'firstName': 'Cuenta',
        'lastName': 'Prueba',
        'institution': 'institution',
        'campus': 'campus',
        'permissions': ['eventos.ver', 'eventos.crear', 'eventos.editar'],
        'activeStudentId': 'child-a',
        'studentIds': ['child-a', 'child-b'],
      },
      role == 'Familiar'
          ? 'family'
          : role == 'Estudiante'
          ? 'child-a'
          : 'teacher',
    ),
  );

Widget app(String role, Widget screen) => ChangeNotifierProvider.value(
  value: provider(role),
  child: MaterialApp(home: screen),
);
Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      220,
      maxScrolls: 40,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final selection = ActiveStudentChannelStub();
  setUpAll(ActiveStudentChannelStub.initialize);
  setUp(selection.install);
  tearDown(selection.uninstall);

  test(
    'modelos conservan tipo, COP cero, revisiones y fecha individual canónica',
    () {
      final model = SchoolEvent.fromMap(eventData(type: 'parent_meeting'));
      expect(model.typeLabel, 'Reunión de padres');
      expect(model.isPresentation, false);
      expect(model.toDraftMap()['schemaVersion'], 2);
      expect(EventRequirement.fromMap({'amountCop': 0}).amountCop, 0);
      expect(EventRequirement.fromMap({}).amountCop, isNull);
      expect(eventCop(2500000), 'COP \$2.500.000');
      final completion = EventCompletion.fromMap({
        'completed': true,
        'completedAtMillis': 1000,
        'performedByName': 'Sara',
        'revision': 3,
      });
      expect(completion.markedAt?.millisecondsSinceEpoch, 1000);
      expect(completion.markedBy, 'Sara');
      expect(completion.revision, 3);
    },
  );

  testWidgets(
    'reunión no muestra alimentos y estudiante solo consulta a 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = Gateway(type: 'parent_meeting');
      await tester.pumpWidget(
        app(
          'Estudiante',
          EventDetailScreen(eventId: 'event', service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Alimentos'), findsNothing);
      expect(find.text('Registrar cumplimiento'), findsNothing);
      expect(find.text('Agregar material o traje'), findsNothing);
      expect(find.text('COP \$0'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Mi registro · Pendiente'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Mi registro · Pendiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('enlace inicial abre detalle revalidado por servicio', (
    tester,
  ) async {
    final service = Gateway();
    await tester.pumpWidget(
      app('Docente', EventsScreen(service: service, initialEventId: 'event')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Detalle del evento'), findsOneWidget);
    expect(service.requests['detail']?.single['eventId'], 'event');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cambiar hijo quita ficha vieja y fallo no muestra datos anteriores',
    (tester) async {
      final second = Completer<EventDetail>();
      final service = Gateway(caps: {'canOrder': true});
      service.onDetail = (child) async =>
          child == 'child-a' ? service.value(child: child) : second.future;
      await tester.pumpWidget(
        app('Familiar', EventDetailScreen(eventId: 'event', service: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ficha de child-a'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bruno').last);
      await tester.pump();
      expect(find.text('Ficha de child-a'), findsNothing);
      second.completeError(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: '[cloud_firestore/permission-denied] raw-secret',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ficha de child-a'), findsNothing);
      expect(find.textContaining('raw-secret'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'familiar ve cumplimientos propios y del hijo, nunca marca a otra persona',
    (tester) async {
      final service = Gateway(
        completions: [
          {
            'id': 'completion',
            'requirementId': 'meeting',
            'targetType': 'family',
            'targetId': 'family',
            'completed': true,
            'completedAtMillis': 1000,
            'performedByName': 'Sara',
          },
        ],
      );
      await tester.pumpWidget(
        app('Familiar', EventDetailScreen(eventId: 'event', service: service)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Mi registro familiar · Cumplido'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Mi registro familiar · Cumplido'),
        findsOneWidget,
      );
      expect(find.textContaining('Ana · Pendiente'), findsOneWidget);
      expect(find.textContaining('Padre Ana'), findsNothing);
      expect(find.text('Registrar cumplimiento'), findsNothing);
    },
  );

  testWidgets(
    'catálogo admin crea importe entero; docente sin capacidad no lo modifica',
    (tester) async {
      final service = Gateway(draft: true, caps: {'canConfigure': true});
      await tester.pumpWidget(
        app(
          'Administrador',
          EventDetailScreen(eventId: 'event', service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Agregar alimento');
      await tester.enterText(field('Nombre'), 'Empanada');
      await tester.enterText(field('Precio COP'), '2500.50');
      await tapText(tester, 'Guardar');
      expect(service.requests['food'], isNull);
      await tester.enterText(field('Precio COP'), '3000');
      await tapText(tester, 'Guardar');
      expect(service.requests['food']?.single['priceCop'], 3000);
      expect(service.requests['food']?.single['expectedRevision'], 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(
          'Docente',
          EventDetailScreen(
            key: UniqueKey(),
            eventId: 'event',
            service: Gateway(caps: {'canManageMaterials': true}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Agregar alimento'), findsNothing);
      expect(find.text('Agregar material o traje'), findsOneWidget);
    },
  );

  testWidgets(
    'material opcional conserva cero y grupos al guardar, sin descartar controles',
    (tester) async {
      final service = Gateway(caps: {'canManageMaterials': true});
      await tester.pumpWidget(
        app('Docente', EventDetailScreen(eventId: 'event', service: service)),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Agregar material o traje');
      await tester.enterText(field('Nombre'), 'Cartulina');
      await tester.enterText(field('Valor COP (opcional)'), '0');
      await tapText(tester, 'Cuarto A');
      await tapText(tester, 'Guardar');
      expect(service.requests['material']?.single['amountCop'], 0);
      expect(service.requests['material']?.single['groupIds'], ['group']);
      expect(service.requests['material']?.single['expectedRevision'], 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reserva confirma total pero no envía precios de líneas ni marca pago',
    (tester) async {
      final service = Gateway(caps: {'canOrder': true});
      await tester.pumpWidget(
        app('Familiar', EventDetailScreen(eventId: 'event', service: service)),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Reservar alimentos');
      await tester.enterText(find.byType(TextFormField), '2');
      await tapText(tester, 'Guardar');
      expect(service.requests['reserve'], isNull);
      expect(
        find.textContaining('Total a confirmar: COP \$5.000'),
        findsOneWidget,
      );
      await tapText(tester, 'Confirmar');
      final request = service.requests['reserve']!.single;
      expect(request['studentId'], 'child-a');
      expect(request['expectedTotalCop'], 5000);
      expect(request['lines'], [
        {'itemId': 'juice', 'quantity': 2},
      ]);
      expect(request.containsKey('paymentState'), false);
      expect(request['requestId'], isNotEmpty);
      expect(find.text('Registrar pago / entrega'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reserva pagada no permite editar ni cancelar al familiar', (
    tester,
  ) async {
    final service = Gateway(
      caps: {'canOrder': true},
      orders: [
        {
          'id': 'order',
          'familyId': 'family',
          'studentId': 'child-a',
          'paymentState': 'paid',
          'deliveryState': 'pending',
          'state': 'reserved',
          'totalCop': 2500,
        },
      ],
    );
    await tester.pumpWidget(
      app('Familiar', EventDetailScreen(eventId: 'event', service: service)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Editar mi reserva'), findsNothing);
    expect(find.text('Cancelar mi reserva'), findsNothing);
  });

  testWidgets(
    'personal registra pago previo sin ofrecer entrega antes de inicio',
    (tester) async {
      final service = Gateway(
        caps: {'canManageFulfillment': true},
        orders: [
          {
            'id': 'order',
            'familyId': 'family',
            'studentId': 'child-a',
            'familyName': 'Madre Ana',
            'studentName': 'Ana',
            'revision': 4,
            'totalCop': 2500,
          },
        ],
      );
      await tester.pumpWidget(
        app('Docente', EventDetailScreen(eventId: 'event', service: service)),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Registrar pago / entrega');
      expect(find.text('Entrega'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tapText(tester, 'Pago recibido');
      await tester.enterText(field('Motivo / comprobación'), 'Pago comprobado');
      await tapText(tester, 'Guardar');
      expect(service.requests['order'], isNull);
      await tapText(tester, 'Confirmar');
      expect(service.requests['order']?.single['paymentState'], 'paid');
      expect(service.requests['order']?.single['expectedRevision'], 4);
      expect(
        service.requests['order']?.single.containsKey('deliveryState'),
        false,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'QR prepara y requiere confirmación explícita antes del cumplimiento individual',
    (tester) async {
      final service = Gateway(caps: {'canManageFulfillment': true});
      const payload = 'LLQ1:fixture';
      await tester.pumpWidget(
        app(
          'Docente',
          EventDetailScreen(
            eventId: 'event',
            service: service,
            scan: (_) async => payload,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Leer QR para seguimiento');
      expect(service.requests['qr']?.single['payload'], payload);
      expect(service.requests['completion'], isNull);
      await tester.enterText(
        field('Motivo / comprobación'),
        'Material recibido',
      );
      await tapText(tester, 'Guardar');
      expect(service.requests['completion'], isNull);
      await tapText(tester, 'Confirmar');
      final request = service.requests['completion']!.single;
      expect(request['qrPayload'], payload);
      expect(request['targetId'], 'child-a');
      expect(request['targetType'], 'student');
      expect(request['requirementId'], 'kit');
      expect(request['expectedRevision'], 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('QR cancelado no prepara ni guarda nada', (tester) async {
    final service = Gateway(caps: {'canManageFulfillment': true});
    await tester.pumpWidget(
      app(
        'Docente',
        EventDetailScreen(
          eventId: 'event',
          service: service,
          scan: (_) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapText(tester, 'Leer QR para seguimiento');
    expect(service.requests['qr'], isNull);
    expect(service.requests['completion'], isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'crear evento en tres pasos conserva tipo subtítulo y audiencia',
    (tester) async {
      final service = Gateway();
      final scope = await service.contexts();
      await tester.pumpWidget(
        app(
          'Administrador',
          EventEditorScreen(eventContext: scope, service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tapText(tester, 'Reunión de padres');
      await tester.enterText(field('Título'), 'Reunión de inicio');
      await tester.enterText(field('Subtítulo (opcional)'), 'Cuarto A');
      await tester.enterText(field('Descripción'), 'Agenda de convivencia');
      await tester.enterText(field('Lugar'), 'Salón');
      await tapText(tester, 'Continuar');
      await tapText(tester, 'Cuarto A');
      await tapText(tester, 'Continuar');
      await tapText(tester, 'Guardar borrador');
      final request = service.requests['draft']!.single;
      expect(request['eventType'], 'parent_meeting');
      expect(request['subtitle'], 'Cuarto A');
      expect(request['foodEnabled'], false);
      expect(request['targetGroupIds'], ['group']);
      expect(request['responsibleUserIds'], ['teacher']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reintento de reserva tras fallo de red conserva identificador y total',
    (tester) async {
      final service = Gateway(caps: {'canOrder': true})
        ..reserveError = FirebaseFunctionsException(
          code: 'unavailable',
          message: 'INTERNAL',
        );
      await tester.pumpWidget(
        app('Familiar', EventDetailScreen(eventId: 'event', service: service)),
      );
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 2; attempt++) {
        await tapText(tester, 'Reservar alimentos');
        await tester.enterText(find.byType(TextFormField), '2');
        await tapText(tester, 'Guardar');
        await tapText(tester, 'Confirmar');
        expect(find.textContaining('INTERNAL'), findsNothing);
      }
      final requests = service.requests['reserve']!;
      expect(requests, hasLength(2));
      expect(requests.first['requestId'], requests.last['requestId']);
      expect(requests.last['expectedTotalCop'], 5000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'precio cambiado recarga catálogo y exige otra confirmación del nuevo total',
    (tester) async {
      final service = Gateway(caps: {'canOrder': true});
      await tester.pumpWidget(
        app('Familiar', EventDetailScreen(eventId: 'event', service: service)),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Reservar alimentos');
      await tester.enterText(find.byType(TextFormField), '2');
      await tapText(tester, 'Guardar');
      service.food.first['priceCop'] = 3000;
      service.reserveError = FirebaseFunctionsException(
        code: 'aborted',
        message: 'Cambió el precio. Revisa el catálogo.',
      );
      await tapText(tester, 'Confirmar');
      expect(service.requests['detail']!.length, 2);
      service.reserveError = null;
      await tapText(tester, 'Reservar alimentos');
      await tester.enterText(find.byType(TextFormField), '2');
      await tapText(tester, 'Guardar');
      expect(
        find.textContaining('Total a confirmar: COP \$6.000'),
        findsOneWidget,
      );
      expect(service.requests['reserve'], hasLength(1));
      await tapText(tester, 'Confirmar');
      expect(service.requests['reserve']!.last['expectedTotalCop'], 6000);
      expect(
        service.requests['reserve']!.first['requestId'],
        isNot(service.requests['reserve']!.last['requestId']),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'requisito admin en diálogo estrecho preserva campos base y requisito anterior',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = Gateway(draft: true, caps: {'canConfigure': true});
      await tester.pumpWidget(
        app(
          'Administrador',
          EventDetailScreen(eventId: 'event', service: service),
        ),
      );
      await tester.pumpAndSettle();
      await tapText(tester, 'Agregar requisito');
      await tester.enterText(field('Requisito'), 'Autorización impresa');
      await tapText(tester, 'Guardar');
      final request = service.requests['draft']!.single;
      expect(request['expectedRevision'], 3);
      expect(request['title'], 'Encuentro del colegio');
      expect(request['eventType'], 'student_presentation');
      expect(request['requirements'], hasLength(3));
      expect(request['publicity'], service.event['publicity']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'docente ve checklist por cada familiar; una marca no completa al segundo ni al hermano',
    (tester) async {
      final service = Gateway(
        started: true,
        caps: {'canManageFulfillment': true},
        completions: [
          {
            'requirementId': 'meeting',
            'targetType': 'family',
            'targetId': 'family',
            'completed': true,
            'studentContextIds': ['child-a', 'child-b'],
            'completedAtMillis': 1000,
            'performedByName': 'Sara',
          },
        ],
      );
      await tester.pumpWidget(
        app('Docente', EventDetailScreen(eventId: 'event', service: service)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Madre Ana · Cumplido'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Madre Ana · Cumplido'), findsOneWidget);
      expect(find.textContaining('Padre Ana · Pendiente'), findsOneWidget);
      expect(find.textContaining('Ana · Pendiente'), findsWidgets);
      expect(find.textContaining('Bruno · Pendiente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notificación A a B reemplaza la ficha abierta y reconstrucción idéntica no duplica',
    (tester) async {
      final service = Gateway();
      final requested = ValueNotifier('event-a');
      addTearDown(requested.dispose);
      await tester.pumpWidget(
        app(
          'Docente',
          ValueListenableBuilder<String>(
            valueListenable: requested,
            builder: (_, id, _) =>
                EventsScreen(initialEventId: id, service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EventDetailScreen>(find.byType(EventDetailScreen))
            .eventId,
        'event-a',
      );
      requested.value = 'event-b';
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EventDetailScreen>(find.byType(EventDetailScreen))
            .eventId,
        'event-b',
      );
      expect(service.requests['detail']!.map((r) => r['eventId']), [
        'event-a',
        'event-b',
      ]);
      requested.value = ' event-b ';
      await tester.pumpAndSettle();
      expect(service.requests['detail'], hasLength(2));
      Navigator.of(tester.element(find.byType(EventDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailScreen), findsNothing);
      expect(find.byType(EventsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notificación nueva durante selección familiar espera al hijo y descarta id anterior',
    (tester) async {
      final children = Completer<List<EventChild>>();
      final service = Gateway()..onChildren = (() => children.future);
      final requested = ValueNotifier('event-a');
      addTearDown(requested.dispose);
      await tester.pumpWidget(
        app(
          'Familiar',
          ValueListenableBuilder<String>(
            valueListenable: requested,
            builder: (_, id, _) =>
                EventsScreen(initialEventId: id, service: service),
          ),
        ),
      );
      await tester.pump();
      requested.value = 'event-b';
      await tester.pump();
      expect(service.requests['detail'], isNull);
      children.complete(service.childrenList);
      await tester.pumpAndSettle();
      expect(service.requests['detail']!.single, {
        'eventId': 'event-b',
        'studentId': 'child-a',
      });
      expect(
        tester
            .widget<EventDetailScreen>(find.byType(EventDetailScreen))
            .eventId,
        'event-b',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notificación respeta hijo cambiado dentro de la ficha familiar',
    (tester) async {
      final service = Gateway();
      final requested = ValueNotifier('event-a');
      addTearDown(requested.dispose);
      await tester.pumpWidget(
        app(
          'Familiar',
          ValueListenableBuilder<String>(
            valueListenable: requested,
            builder: (_, id, _) =>
                EventsScreen(initialEventId: id, service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bruno').last);
      await tester.pumpAndSettle();
      requested.value = 'event-b';
      await tester.pumpAndSettle();
      expect(service.requests['detail']!.last, {
        'eventId': 'event-b',
        'studentId': 'child-b',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('enlace pendiente nunca abre ficha después de salir de Eventos', (
    tester,
  ) async {
    final children = Completer<List<EventChild>>();
    final service = Gateway()..onChildren = (() => children.future);
    await tester.pumpWidget(
      app(
        'Familiar',
        EventsScreen(initialEventId: 'event-a', service: service),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    children.complete(service.childrenList);
    await tester.pumpAndSettle();
    expect(service.requests['detail'], isNull);
    expect(tester.takeException(), isNull);
  });
}
