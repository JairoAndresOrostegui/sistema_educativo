/// Public build configuration. Production never inherits QA credentials.
class AppEnvironment {
  static const name = String.fromEnvironment('APP_ENV', defaultValue: 'qa');
  static bool get isProduction {
    if (name != 'qa' && name != 'prod') {
      throw StateError('APP_ENV debe ser qa o prod.');
    }
    return name == 'prod';
  }

  static void validateWebHost(String host) {
    const productionHosts = {
      'liceobilinguerodolfollinas.edu.co',
      'www.liceobilinguerodolfollinas.edu.co',
      'sistema-educativo-rl-prod.web.app',
      'sistema-educativo-rl-prod.firebaseapp.com',
    };
    if (!isProduction && productionHosts.contains(host)) {
      throw StateError('Una compilación QA no puede ejecutarse en producción.');
    }
    if (isProduction &&
        (host == 'sistema-educativo-rl.web.app' ||
            host == 'sistema-educativo-rl.firebaseapp.com')) {
      throw StateError(
        'Una compilación de producción no puede ejecutarse en QA.',
      );
    }
  }

  static String? get webVapidKey {
    const supplied = String.fromEnvironment('WEB_VAPID_KEY');
    if (supplied.isNotEmpty) return supplied;
    if (isProduction) return null;
    return 'BCWDKdFxjGMarEkk6xvvs5jw0mnJEN22UFAKmd-DbT7Lwipt4rwHhKTnF0GaTphnkk0-CmCerzJIidz8kkfrV-s';
  }
}
