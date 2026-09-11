import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sistema_educativo/models/file/file_model.dart';
import 'package:sistema_educativo/models/messaging/message_models.dart';
import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/modules/file/services/file_service.dart';
import 'package:sistema_educativo/modules/messaging/services/messaging_service.dart';
import 'package:sistema_educativo/utils/private_document_downloader.dart';

class _Downloads extends Fake implements PrivateDocumentDownloader {
  Uint8List? bytes = Uint8List.fromList([1, 2, 3]);
  Object? error;
  String? endpoint;
  Map<String, String>? parameters;

  @override
  Future<Uint8List> download({
    required String endpoint,
    required Map<String, String> parameters,
  }) async {
    this.endpoint = endpoint;
    this.parameters = parameters;
    if (error != null) throw error!;
    if (bytes == null) throw StateError('Documento no disponible.');
    return bytes!;
  }
}

// Any Storage access in download tests fails: it must use the backend instead.
class _Storage extends Fake implements FirebaseStorage {}

class _Result<T> implements HttpsCallableResult<T> {
  _Result(this.data);
  @override
  final T data;
}

class _Callable extends Fake implements HttpsCallable {
  _Callable(this.data);
  final Object data;
  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async =>
      _Result(data as T);
}

class _Functions extends Fake implements FirebaseFunctions {
  Object data = <String, dynamic>{'children': <dynamic>[]};
  String? called;
  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) {
    called = name;
    return _Callable(data);
  }
}

class _Firestore extends Fake implements FirebaseFirestore {}

void main() {
  late _Storage storage;
  late _Functions functions;
  late _Downloads downloads;
  late FileService fileService;
  late MessagingService messagingService;
  setUp(() {
    storage = _Storage();
    functions = _Functions();
    downloads = _Downloads();
    fileService = FileService(
      storage: storage,
      functions: functions,
      downloads: downloads,
    );
    messagingService = MessagingService(
      storage: storage,
      functions: functions,
      firestore: _Firestore(),
      downloads: downloads,
    );
  });
  final file = FileModel.fromMap({
    'name': 'circular.pdf',
    'storagePath': 'files/a/circular.pdf',
  }, id: 'a');
  const attachment = MessageAttachment(
    id: 'a',
    name: 'circular.pdf',
    contentType: 'application/pdf',
    sizeBytes: 3,
    storagePath: 'message_attachments/chat/a/circular.pdf',
  );

  test('Archivos descarga por backend sin emitir URL Storage', () async {
    expect(await fileService.downloadBytes(file), [1, 2, 3]);
    expect(downloads.endpoint, 'descargarArchivoProtegido');
    expect(downloads.parameters, {'fileId': file.id});
  });
  test('archivo en eliminacion conserva estado y bloquea descarga', () async {
    final deleting = FileModel.fromMap({
      'name': 'circular.pdf',
      'storagePath': 'files/a/circular.pdf',
      'status': 'deleting',
    }, id: 'a');
    expect(deleting.isDeleting, isTrue);
    await expectLater(fileService.downloadBytes(deleting), throwsStateError);
    expect(downloads.endpoint, isNull);
  });
  test('Mensajeria descarga bytes autenticados sin emitir URL token', () async {
    expect(await messagingService.attachmentDownloadBytes(attachment), [
      1,
      2,
      3,
    ]);
    expect(downloads.endpoint, 'descargarAdjuntoProtegido');
    expect(downloads.parameters, {'attachmentId': attachment.id});
  });
  test(
    'revocacion y ausencia de bytes no se presentan como descarga exitosa',
    () async {
      downloads.error = FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthorized',
      );
      await expectLater(
        fileService.downloadBytes(file),
        throwsA(isA<FirebaseException>()),
      );
      await expectLater(
        messagingService.attachmentDownloadBytes(attachment),
        throwsA(isA<FirebaseException>()),
      );
      downloads.error = null;
      downloads.bytes = null;
      await expectLater(fileService.downloadBytes(file), throwsStateError);
      await expectLater(
        messagingService.attachmentDownloadBytes(attachment),
        throwsStateError,
      );
    },
  );
  test('HTTP usa Bearer y devuelve bytes, nunca token en URL', () async {
    final downloader = PrivateDocumentDownloader(
      projectId: 'school-qa',
      tokenProvider: () async => 'secret-id-token',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer secret-id-token');
        expect(request.url.host, 'us-central1-school-qa.cloudfunctions.net');
        expect(request.url.queryParameters, {'fileId': 'document-1'});
        expect(request.followRedirects, isFalse);
        return http.Response.bytes([1, 2, 3], 200);
      }),
    );
    expect(
      await downloader.download(
        endpoint: 'descargarArchivoProtegido',
        parameters: {'fileId': 'document-1'},
      ),
      [1, 2, 3],
    );
  });
  test(
    'HTTP no publica errores internos ni acepta respuestas vacías',
    () async {
      for (final status in [401, 403, 404, 409, 500, 302, 200]) {
        final downloader = PrivateDocumentDownloader(
          projectId: 'school-qa',
          tokenProvider: () async => 'token',
          client: MockClient(
            (_) async => http.Response(
              status == 200 ? '' : 'raw internal stack exception',
              status,
            ),
          ),
        );
        await expectLater(
          downloader.download(
            endpoint: 'descargarArchivoProtegido',
            parameters: {'fileId': 'a'},
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'mensaje seguro',
              isNot(contains('raw internal')),
            ),
          ),
        );
      }
    },
  );
  test('HTTP limita a 25 MiB aun si servidor omite tamaño', () async {
    final downloader = PrivateDocumentDownloader(
      projectId: 'school-qa',
      tokenProvider: () async => 'token',
      client: MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.fromIterable([
            Uint8List(PrivateDocumentDownloader.maxBytes),
            Uint8List(1),
          ]),
          200,
        ),
      ),
    );
    await expectLater(
      downloader.download(
        endpoint: 'descargarArchivoProtegido',
        parameters: {'fileId': 'a'},
      ),
      throwsStateError,
    );
  });
  test('familia obtiene sus hijos por backend sin listar directorio', () async {
    final family = userModelv2.fromFirestore({
      'role': 'Familiar',
      'institution': 'i',
      'campus': 'c',
      'studentIds': ['outdated-local-child'],
    }, 'family');
    functions.data = {
      'children': [
        {
          'id': 's1',
          'firstName': 'Ana',
          'lastName': 'Prueba',
          'status': 'activo',
          'institution': 'i',
          'campus': 'c',
          'groupId': 'g1',
          'groupName': 'Cuarto A',
        },
        {'id': 's2', 'status': 'inactivo', 'institution': 'i', 'campus': 'c'},
        {'id': 's3', 'status': 'activo', 'institution': 'other', 'campus': 'c'},
      ],
    };
    final children = await messagingService.getFamilyChildren(family);
    expect(functions.called, 'obtenerHijosVinculados');
    expect(children.map((child) => child.id), ['s1']);
    expect(children.single.fullName, 'Ana Prueba');
    expect(children.single.groupId, 'g1');
  });
}
