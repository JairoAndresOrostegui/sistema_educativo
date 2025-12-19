import 'package:flutter/material.dart';

import '../../../utils/validators.dart';
import '../services/auth_service_v2.dart';

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key});

  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recuperar contrasena'),
      content: Form(
        key: _formKey,
        child: Semantics(
          label: 'Campo de correo electronico para recuperar contrasena',
          hint: 'Ingrese su correo institucional',
          textField: true,
          enabled: true,
          focusable: true,
          child: TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Correo electronico'),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Campo obligatorio';
              }
              if (!Validators.isValidEmail(value)) {
                return 'Correo invalido';
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        Semantics(
          label: 'Boton para cancelar recuperacion de contrasena',
          button: true,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ),
        Semantics(
          label: 'Boton para enviar correo de recuperacion de contrasena',
          button: true,
          child: ElevatedButton(
            onPressed: _loading ? null : _enviarCorreo,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar'),
          ),
        ),
      ],
    );
  }

  Future<void> _enviarCorreo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final email = _emailController.text.trim();
    String mensaje;

    try {
      await AuthService().sendPasswordResetEmail(email);
      mensaje = 'Se ha enviado un enlace para restablecer la contrasena.';
    } catch (e) {
      mensaje = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);

    Future.microtask(() {
      if (!mounted) return;
      showDialog(
        context: navigator.context,
        builder: (_) => AlertDialog(
          title: const Text('Recuperacion de contrasena'),
          content: Text(mensaje),
          actions: [
            Semantics(
              label: 'Boton para cerrar el mensaje de recuperacion de contrasena',
              button: true,
              child: TextButton(
                onPressed: () => Navigator.pop(navigator.context),
                child: const Text('Aceptar'),
              ),
            ),
          ],
        ),
      );
    });
  }
}
