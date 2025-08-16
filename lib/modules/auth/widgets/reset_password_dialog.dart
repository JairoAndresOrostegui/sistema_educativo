import 'package:flutter/material.dart';
import '../services/authServiceV2.dart';

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
      title: const Text('Recuperar contraseña'),
      content: Form(
        key: _formKey,
        child: Semantics(
          label: 'Campo de correo electrónico para recuperar contraseña',
          hint: 'Ingrese su correo institucional',
          textField: true,
          enabled: true,
          focusable: true,
          child: TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
            keyboardType: TextInputType.emailAddress,
            validator:
                (value) =>
                    value == null || value.isEmpty ? 'Campo obligatorio' : null,
          ),
        ),
      ),
      actions: [
        Semantics(
          label: 'Botón para cancelar recuperación de contraseña',
          button: true,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ),
        Semantics(
          label: 'Botón para enviar correo de recuperación de contraseña',
          button: true,
          child: ElevatedButton(
            onPressed: _loading ? null : _enviarCorreo,
            child:
                _loading
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
      mensaje = 'Se ha enviado un enlace para restablecer la contraseña.';
    } catch (e) {
      mensaje = e.toString().replaceAll('Exception: ', '');
    }

    if (!mounted) return;
    final ctx = Navigator.of(context, rootNavigator: true).context;
    Navigator.pop(context); // cerrar diálogo actual

    Future.delayed(Duration.zero, () {
      showDialog(
        context: ctx,
        builder:
            (_) => AlertDialog(
              title: const Text('Recuperación de contraseña'),
              content: Text(mensaje),
              actions: [
                Semantics(
                  label:
                      'Botón para cerrar el mensaje de recuperación de contraseña',
                  button: true,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Aceptar'),
                  ),
                ),
              ],
            ),
      );
    });
  }
}
