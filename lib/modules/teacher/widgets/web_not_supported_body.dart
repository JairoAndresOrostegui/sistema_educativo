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
          'Gestionar Ruta',
          style: TextStyle(color: Colors.red),
        ),
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Solo disponible en móvil: gestión de ubicación.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}