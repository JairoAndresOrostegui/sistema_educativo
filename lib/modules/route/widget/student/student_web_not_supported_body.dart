import 'package:flutter/material.dart';

class WebNotSupportedBody extends StatelessWidget {
  const WebNotSupportedBody({super.key});

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
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'La vista del mapa solo está disponible en dispositivos móviles. Por favor, usa la aplicación en un teléfono o tablet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
            semanticsLabel:
                'Mensaje informativo: La vista del mapa solo está disponible en dispositivos móviles. Por favor, usa la aplicación en un teléfono o tablet.',
          ),
        ),
      ),
    );
  }
}
