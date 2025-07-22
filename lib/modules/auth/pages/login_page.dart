 import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool isLoading = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (user != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final rol = data?['rol'];

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (rol == 'admin') {
                  Navigator.pushReplacementNamed(context, '/admin_dashboard');
                } else if (rol == 'docente') {
                  Navigator.pushReplacementNamed(context, '/docente_dashboard');
                } else if (rol == 'estudiante') {
                  Navigator.pushReplacementNamed(context, '/estudiante_dashboard');
                } else {
                  FirebaseAuth.instance.signOut();
                }
              });

              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('assets/logo.jpg', height: isMobile ? 60 : 80),
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
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(labelText: 'Correo electrónico'),
                                validator: (value) => value!.isEmpty ? 'Ingrese su correo' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Contraseña'),
                                validator: (value) => value!.isEmpty ? 'Ingrese su contraseña' : null,
                              ),
                              const SizedBox(height: 24),
                              if (error != null)
                                Text(error!, style: const TextStyle(color: Colors.red)),
                              isLoading
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton(
                                      onPressed: _login,
                                      child: const Text('Iniciar sesión'),
                                    ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  final correoActual = _emailController.text.trim();
                                  final controller = TextEditingController(text: correoActual);
                                  showDialog(
                                    context: context,
                                    builder: (ctx) {
                                      return AlertDialog(
                                        title: const Text('Restablecer contraseña'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Enviaremos un enlace al siguiente correo:'),
                                            const SizedBox(height: 12),
                                            TextField(
                                              controller: controller,
                                              readOnly: true,
                                              decoration: const InputDecoration(labelText: 'Correo electrónico'),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: correoActual.isEmpty
                                                ? null
                                                : () async {
                                                    Navigator.pop(ctx);
                                                    try {
                                                      await FirebaseAuth.instance
                                                          .sendPasswordResetEmail(email: correoActual);
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Se envió el enlace a $correoActual')),
                                                      );
                                                    } catch (e) {
                                                      if (!mounted) return;
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Error: $e')),
                                                      );
                                                    }
                                                  },
                                            child: const Text('Enviar'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                child: const Text('¿Olvidaste tu contraseña?'),
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
      },
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user != null) {
        final firestore = FirebaseFirestore.instance;
        final token = await FirebaseMessaging.instance.getToken();

        if (token != null && token.isNotEmpty) {
          final coincidencias = await firestore
              .collection('usuarios')
              .where('fcmToken', isEqualTo: token)
              .get();

          for (final doc in coincidencias.docs) {
            if (doc.id != user.uid) {
              await firestore.collection('usuarios').doc(doc.id).update({
                'fcmToken': FieldValue.delete(),
              });
            }
          }

          await firestore.collection('usuarios').doc(user.uid).update({
            'fcmToken': token,
          });

        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message ?? 'Error al iniciar sesión';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Ocurrió un error inesperado.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
