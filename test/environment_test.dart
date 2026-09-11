import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_educativo/config/app_environment.dart';
import 'package:sistema_educativo/config/firebase_options.dart';

void main() {
  test('Known opposite-environment web host is rejected', () {
    expect(
      () => AppEnvironment.validateWebHost(
        AppEnvironment.isProduction
            ? 'sistema-educativo-rl.web.app'
            : 'liceobilinguerodolfollinas.edu.co',
      ),
      throwsStateError,
    );
    expect(() => AppEnvironment.validateWebHost('localhost'), returnsNormally);
  });
  test(
    'Android uses the selected environment, with isolated app identifiers',
    () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final selected = DefaultFirebaseOptions.currentPlatform;
      expect(
        selected.projectId,
        AppEnvironment.isProduction
            ? 'sistema-educativo-rl-prod'
            : 'sistema-educativo-rl',
      );
      expect(
        DefaultFirebaseOptions.android.appId,
        '1:732639994966:android:ad6ec170c7f782b8e847f7',
      );
      expect(
        DefaultFirebaseOptions.productionAndroid.appId,
        '1:325430927285:android:2eecce415faf28dee103fc',
      );
      expect(
        DefaultFirebaseOptions.productionWeb.projectId,
        DefaultFirebaseOptions.productionAndroid.projectId,
      );
    },
  );
  test('Production never inherits the QA VAPID key', () {
    if (AppEnvironment.isProduction) expect(AppEnvironment.webVapidKey, isNull);
  });
}
