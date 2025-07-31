  import 'package:flutter/material.dart';

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
          'Gestionar Ruta',
          style: TextStyle(color: Colors.red),
        ),
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: isRequesting ? null : onRequestPermission,
          child: Text(
            isRequesting ? 'Solicitando permisos...' : 'Permitir ubicación',
          ),
        ),
      ),
    );
  }
}