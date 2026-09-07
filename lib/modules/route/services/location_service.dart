import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'daily_route_service.dart';

class LocationService {
  StreamSubscription<Position>? _positionSub;

  static const double _kMinDeltaMeters = 30;
  static const Duration _kMinInterval = Duration(seconds: 30);
  static const Duration _kMaxInterval = Duration(seconds: 45);

  GeoPoint? _lastWrittenPoint;
  DateTime? _lastWriteAt;

  LocationService();

  Future<bool> requestLocationPermission() async {
    if (kIsWeb) {
      final status = await Geolocator.requestPermission();
      return status == LocationPermission.whileInUse ||
          status == LocationPermission.always;
    }
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<void> startLocationUpdates(String rutaDiaDocId) async {
    final ok = await requestLocationPermission();
    if (!ok) {
      throw StateError(
        'Permiso de ubicación denegado. Puedes operar manualmente; activa el permiso en Ajustes para compartir posición.',
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Activa el GPS para compartir la ubicación de la ruta.');
    }

    await _positionSub?.cancel();

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

    final settings = (defaultTargetPlatform == TargetPlatform.android)
        ? AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 25,
            intervalDuration: const Duration(seconds: 30),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Recorrido escolar activo',
              notificationText: 'Compartiendo ubicación durante el recorrido.',
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 25,
          );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) async {
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

      await RouteOperations.execute(docId, 'position', {
        'latitude': point.latitude,
        'longitude': point.longitude,
      });

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
