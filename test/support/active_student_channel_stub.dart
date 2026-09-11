import 'package:firebase_core/firebase_core.dart';
// FlutterFire's existing native test bridge; no application dependency changes.
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class ActiveStudentChannelStub {
  final List<String> selected = [];
  String? deniedStudentId;

  static const _channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
    StandardMessageCodec(),
  );

  void install() {
    selected.clear();
    deniedStudentId = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(_channel, (message) async {
          final arguments = (message! as List).single as Map;
          expect(arguments['functionName'], 'seleccionarHijoActivo');
          final studentId =
              (arguments['parameters'] as Map)['studentId'] as String;
          selected.add(studentId);
          if (studentId == deniedStudentId) {
            return ['permission-denied', 'PERMISSION_DENIED', null];
          }
          return [
            {'revision': selected.length + 1},
          ];
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(_channel, null);
  }

  static Future<void> initialize() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  }
}
