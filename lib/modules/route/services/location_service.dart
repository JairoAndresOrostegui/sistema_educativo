import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  StreamSubscription<Position>? _positionSub;
  final FirebaseFirestore _firestore;

  static const double _kMinDeltaMeters = 30;
  static const Duration _kMinInterval = Duration(seconds: 8);
  static const Duration _kMaxInterval = Duration(seconds: 45);

  GeoPoint? _lastWrittenPoint;
  DateTime? _lastWriteAt;

  LocationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<bool> requestLocationPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<void> startLocationUpdates(String rutaDiaDocId) async {
    final ok = await requestLocationPermission();
    if (!ok) {
      debugPrint('LocationService: permisos denegados');
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('LocationService: servicio de ubicación desactivado');
      return;
    }

    _positionSub?.cancel();

    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      );
      await _writeIfNeeded(
        rutaDiaDocId,
        GeoPoint(first.latitude, first.longitude),
        force: true,
      );
    } catch (e) {
      debugPrint('LocationService: error en posición inicial -> $e');
    }

    final settings =
        (defaultTargetPlatform == TargetPlatform.android)
            ? AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 25,
              intervalDuration: const Duration(
                seconds: 10,
              ),
            )
            : const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 25,
            );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((pos) async {
      try {
        await _writeIfNeeded(
          rutaDiaDocId,
          GeoPoint(pos.latitude, pos.longitude),
        );
      } catch (e) {
        debugPrint('LocationService: error procesando posición -> $e');
      }
    });
  }

  Future<void> _writeIfNeeded(
    String docId,
    GeoPoint point, {
    bool force = false,
  }) async {
    try {
      final now = DateTime.now();

      if (!force && _lastWrittenPoint != null && _lastWriteAt != null) {
        final moved = Geolocator.distanceBetween(
          _lastWrittenPoint!.latitude,
          _lastWrittenPoint!.longitude,
          point.latitude,
          point.longitude,
        );
        final elapsed = now.difference(_lastWriteAt!);

        final byMovement =
            moved >= _kMinDeltaMeters && elapsed >= _kMinInterval;
        final byMaxAge = elapsed >= _kMaxInterval;

        if (!byMovement && !byMaxAge) {
          return;
        }
      }

      await _firestore.collection('daily_routes').doc(docId).set({
        'teacherPosition': point,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _lastWrittenPoint = point;
      _lastWriteAt = now;
    } catch (e) {
      debugPrint('LocationService: error actualizando ubicación -> $e');
    }
  }

  void stopLocationUpdates() {
    _positionSub?.cancel();
    _positionSub = null;
    _lastWrittenPoint = null;
    _lastWriteAt = null;
  }
}
