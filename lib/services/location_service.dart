import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Para Timestamp

class LocationService {
  StreamSubscription<Position>? _positionSub;
  final FirebaseFirestore _firestore;

  LocationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<bool> requestLocationPermission() async {
    if (kIsWeb) return true; // No permissions needed for web usually

    final status = await Permission.location.request();
    return status.isGranted;
  }

  void startLocationUpdates(String rutaDiaDocId) {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Actualizar cada 10 metros de cambio
      ),
    ).listen((pos) async {
      final geo = {'lat': pos.latitude, 'lng': pos.longitude};
      await _firestore
          .collection('rutas_diarias')
          .doc(rutaDiaDocId)
          .update({'posicionDocente': geo});
    });
  }

  void stopLocationUpdates() {
    _positionSub?.cancel();
    _positionSub = null;
  }
}