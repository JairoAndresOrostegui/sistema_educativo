import 'package:flutter/material.dart';
import '../../../services/location_permission_service.dart';

class LocationPermissionDeniedBody extends StatelessWidget {
  final bool isRequesting;
  final VoidCallback onRequestPermission;

  const LocationPermissionDeniedBody({
    super.key,
    required this.isRequesting,
    required this.onRequestPermission,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Mi Ruta de Hoy',
          style: TextStyle(color: Colors.red),
          semanticsLabel: 'Mi Ruta de Hoy',
        ),
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 80,
              color: Colors.grey,
              semanticLabel: 'Icono de ubicación denegada',
            ),
            const SizedBox(height: 20),
            const Text(
              'Necesitamos acceso a tu ubicación para mostrar la ruta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
              semanticsLabel:
                  'Mensaje de solicitud de ubicación: Necesitamos acceso a tu ubicación para mostrar la ruta.',
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isRequesting ? null : onRequestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                isRequesting ? 'Solicitando permisos...' : 'Permitir ubicación',
                semanticsLabel:
                    isRequesting
                        ? 'Solicitando permisos de ubicación...'
                        : 'Botón para permitir la ubicación',
              ),
            ),
            if (!isRequesting)
              TextButton(
                onPressed: () async {
                  await LocationPermissionService().openSettings();
                },
                child: const Text(
                  'Abrir Configuración de la App',
                  semanticsLabel:
                      'Botón para abrir la configuración de la aplicación y gestionar permisos.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
