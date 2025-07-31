import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../app.dart';
import '../providers/user_provider.dart';
import '../../../utils/snackbar_utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userInputController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _userInputController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  'assets/logo.jpg',
                  height: isMobile ? 60 : 80,
                  semanticLabel:
                      'Logo del colegio Liceo Bilingüe Rodolfo Llinás',
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Liceo Bilingüe Rodolfo Llinás',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                if (FirebaseAuth.instance.currentUser != null)
                  Icon(Icons.account_circle, size: isMobile ? 30 : 40),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox(
                width: isMobile ? double.infinity : 400,
                child: Card(
                  elevation: 4,
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            label:
                                'Campo para ingresar correo institucional o documento',
                            hint:
                                'Ingrese su correo o documento para iniciar sesión',
                            textField: true,
                            enabled: true,
                            focusable: true,
                            child: TextFormField(
                              controller: _userInputController,
                              decoration: const InputDecoration(
                                labelText: 'Correo institucional o documento',
                              ),
                              validator:
                                  (value) =>
                                      value!.isEmpty
                                          ? 'Este campo es obligatorio'
                                          : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Semantics(
                            label: 'Campo para ingresar la contraseña',
                            hint: 'Ingrese su contraseña para acceder',
                            textField: true,
                            enabled: true,
                            focusable: true,
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                              ),
                              validator:
                                  (value) =>
                                      value!.isEmpty
                                          ? 'Ingrese su contraseña'
                                          : null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (error != null)
                            Semantics(
                              label: 'Mensaje de error',
                              liveRegion: true,
                              child: Text(
                                error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          isLoading
                              ? Semantics(
                                label: 'Cargando, por favor espera',
                                liveRegion: true,
                                child: CircularProgressIndicator(),
                              )
                              : Tooltip(
                                message: 'Presiona para iniciar sesión',
                                child: Semantics(
                                  label: 'Botón para iniciar sesión',
                                  enabled: true,
                                  focusable: true,
                                  button: true,
                                  child: ElevatedButton(
                                    onPressed: _login,
                                    child: const Text('Iniciar sesión'),
                                  ),
                                ),
                              ),
                          const SizedBox(height: 16),
                          Semantics(
                            label: 'Botón para recuperar la contraseña',
                            enabled: true,
                            focusable: true,
                            child: TextButton(
                              onPressed: _recuperarContrasena,
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recuperarContrasena() async {
    final correo = _userInputController.text.trim();
    if (correo.isEmpty || correo.contains(RegExp(r'[0-9]'))) {
      mostrarSnack(
        context,
        'Solo se puede recuperar contraseña por correo institucional',
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
      mostrarSnack(context, 'Se envió el enlace a $correo');
    } catch (e) {
      mostrarSnack(context, 'Error: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final input = _userInputController.text.trim();
      final password = _passwordController.text.trim();
      String email = input;

      // Si es número, buscar el correo institucional por documento
      if (RegExp(r'^\d+$').hasMatch(input)) {
        final consulta =
            await FirebaseFirestore.instance
                .collection('usuarios')
                .where('documento', isEqualTo: input)
                .limit(1)
                .get();

        if (consulta.docs.isEmpty) throw Exception('Documento no encontrado');

        final data = consulta.docs.first.data();
        final rol = data['rol'];

        if (rol != 'estudiante' && rol != 'padre') {
          throw Exception(
            'Solo estudiantes o padres pueden ingresar con documento',
          );
        }

        if (data['correoInstitucional'] == null ||
            data['correoInstitucional'].toString().isEmpty) {
          throw Exception('Este usuario no tiene correo asignado');
        }

        email = data['correoInstitucional'];
      } else {
        // Validar que si es correo institucional, no sea estudiante o padre
        final consulta =
            await FirebaseFirestore.instance
                .collection('usuarios')
                .where('correoInstitucional', isEqualTo: input)
                .limit(1)
                .get();

        if (consulta.docs.isEmpty) throw Exception('Correo no encontrado');
        final data = consulta.docs.first.data();
        final rol = data['rol'];

        if (rol == 'estudiante' || rol == 'padre') {
          throw Exception(
            'Estudiantes y padres no pueden usar correo institucional',
          );
        }
      }

      // Iniciar sesión
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        /*if (!user.emailVerified) {
          throw Exception('Debe verificar su correo antes de iniciar sesión');
        }*/

        final doc =
            await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(user.uid)
                .get();
        final data = doc.data();

        if (data == null || data['estado'] != 'activo') {
          mostrarSnack(
            context,
            'Tu cuenta está inactiva. Contacta a la institución.',
          );
          await FirebaseAuth.instance.signOut();
          return;
        }

        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          final usuarios = FirebaseFirestore.instance.collection('usuarios');
          final coincidencias =
              await usuarios.where('fcmTokens', arrayContains: token).get();

          for (final doc in coincidencias.docs) {
            if (doc.id != user.uid) {
              await usuarios.doc(doc.id).update({
                'fcmTokens': FieldValue.arrayRemove([token]),
              });
            }
          }

          await usuarios.doc(user.uid).update({
            'fcmTokens': FieldValue.arrayUnion([token]),
          });
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => ChangeNotifierProvider(
                  create: (_) => UsuarioProvider()..cargarUsuario(user.uid),
                  child: const AppRouter(),
                ),
          ),
        );
      }
    } catch (e) {
      mostrarSnack(context, _traducirError(e.toString()));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}

String _traducirError(String error) {
  if (error.contains('user-not-found') ||
      error.contains('Documento no encontrado')) {
    return 'Usuario no encontrado. Verifique sus datos.';
  } else if (error.contains('wrong-password')) {
    return 'Contraseña incorrecta.';
  } else if (error.contains('verificar su correo')) {
    return 'Debe verificar su correo antes de ingresar.';
  } else if (error.contains('network-request-failed')) {
    return 'No hay conexión a internet.';
  } else {
    return 'Ocurrió un error inesperado. Intente de nuevo.';
  }
}
