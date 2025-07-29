import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';

// Importaciones de servicios
import '../../../services/location_permission_service.dart';
import '../../../services/my_route_service.dart';

// Importaciones de componentes
import '../widgets/my_routes_body.dart';
import '../widgets/location_permission_denied_body.dart';
import '../widgets/web_not_supported_body.dart';

class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key});

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  // Servicios
  late final LocationPermissionService _locationPermissionService;
  late final MyRouteService _myRouteService;

  // Estado de la pantalla
  GoogleMapController? _mapController;
  LatLng? _teacherPosition;
  bool _locationGranted = false;
  bool _isRequestingPermission = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _locationPermissionService = LocationPermissionService();
    _myRouteService = MyRouteService();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    if (_currentUserId == null) return;
    await _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    setState(() => _isRequestingPermission = true);
    final granted =
        await _locationPermissionService.checkAndRequestPermission();
    setState(() {
      _locationGranted = granted;
      _isRequestingPermission = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _updateTeacherPosition(LatLng newPosition) {
    setState(() {
      _teacherPosition = newPosition;
      _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WebNotSupportedBody();
    }

    if (!_locationGranted) {
      return Semantics(
        label:
            'Permiso de ubicación denegado. Se mostrará una opción para concederlo.',
        child: LocationPermissionDeniedBody(
          isRequesting: _isRequestingPermission,
          onRequestPermission: _checkLocationPermission,
        ),
      );
    }

    if (_currentUserId == null) {
      return Scaffold(
        body: Semantics(
          label: 'Usuario no autenticado. No se puede mostrar la ruta.',
          child: Center(child: Text('Usuario no autenticado.')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Semantics(
          header: true,
          label: 'Mi Ruta de Hoy',
          child: Text('Mi Ruta de Hoy', style: TextStyle(color: Colors.red)),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Semantics(
        label: 'Pantalla de ruta escolar diaria del estudiante',
        child: MyRoutesBody(
          userId: _currentUserId!,
          myRouteService: _myRouteService,
          onMapCreated: _onMapCreated,
          teacherPosition: _teacherPosition,
          updateTeacherPosition: _updateTeacherPosition,
        ),
      ),
    );
  }
}
