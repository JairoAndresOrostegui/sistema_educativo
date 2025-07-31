import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationPermissionService {
  Future<bool> checkAndRequestPermission() async {
    if (kIsWeb) {
      return true;
    }

    final status = await Permission.location.status;
    if (status.isGranted) {
      return true;
    } else {
      final result = await Permission.location.request();
      return result.isGranted;
    }
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
