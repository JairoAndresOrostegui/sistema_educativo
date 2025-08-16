import 'dart:io' show Platform; // se ignora en web
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/user/userModelV2.dart';

class UserLogService {
  final _db = FirebaseFirestore.instance;
  final _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, dynamic>> _collectEnv() async {
    final pkg = await PackageInfo.fromPlatform();
    final common = <String, dynamic>{
      'appVersion': pkg.version,
      'buildNumber': pkg.buildNumber,
      'platform': kIsWeb
          ? 'web'
          : Platform.isAndroid ? 'android'
          : Platform.isIOS ? 'ios'
          : Platform.isMacOS ? 'macos'
          : Platform.isWindows ? 'windows'
          : Platform.isLinux ? 'linux'
          : 'unknown',
    };

    try {
      if (kIsWeb) {
        final info = await _deviceInfo.webBrowserInfo;
        return {
          ...common,
          'browserName': '${info.browserName}',
          'userAgent': info.userAgent,
          'deviceMemoryGb': info.deviceMemory,
          'hardwareConcurrency': info.hardwareConcurrency,
        };
      } else if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return {
          ...common,
          'deviceManufacturer': info.manufacturer,
          'deviceModel': info.model,
          'osVersion': 'Android ${info.version.release} (SDK ${info.version.sdkInt})',
          'isPhysicalDevice': info.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return {
          ...common,
          'deviceModel': info.utsname.machine,
          'osVersion': '${info.systemName} ${info.systemVersion}',
          'isPhysicalDevice': info.isPhysicalDevice,
        };
      } else {
        // macOS / Windows / Linux
        final info = await _deviceInfo.deviceInfo;
        return {
          ...common,
          'deviceModel': info.data['model'] ?? info.data['computerName'],
          'osVersion': info.data['osVersion'] ?? info.data['release'],
        };
      }
    } catch (_) {
      return common; // si algo falla, devolvemos lo básico
    }
  }

  Future<void> logEvent({
    required UserModelV2 user,
    required String event,
    Map<String, dynamic>? extra,
  }) async {
    final env = await _collectEnv();
    final doc = {
      'userId': user.id,
      'fullName': '${user.firstName} ${user.lastName}',
      'role': user.role,
      'institution': user.institution,
      'campus': user.campus,
      'grade': user.grade,
      'event': event, // ej: "login", "logout", "open:files"
      'timestamp': FieldValue.serverTimestamp(),
      'env': env,
      if (extra != null) 'extra': extra,
    };
    await _db.collection('user_logs').add(doc);
  }

  Future<Set<String>> getDownloadedFileKeys({
  required String userId,
  String? grade,
  int limit = 100,
}) async {
  Query q = _db
      .collection('user_logs')
      .where('userId', isEqualTo: userId)
      .where('event', isEqualTo: 'file_download');

  if (grade != null && grade.isNotEmpty) {
    q = q.where('extra.grade', isEqualTo: grade);
  }

  final snap = await q.orderBy('timestamp', descending: true).limit(limit).get();

  final out = <String>{};
  for (final d in snap.docs) {
    final data = d.data() as Map<String, dynamic>;
    final extra = (data['extra'] ?? {}) as Map<String, dynamic>;
    final fileId = (extra['fileId'] as String?)?.trim() ?? '';
    final url = (extra['url'] as String?)?.trim() ?? '';
    final key = fileId.isNotEmpty ? fileId : url; // debe coincidir con _fileKey(...)
    if (key.isNotEmpty) out.add(key);
  }
  return out;
}

}
