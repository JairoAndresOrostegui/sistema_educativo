import 'package:flutter/material.dart';
import 'package:sistema_educativo/config/app_palette.dart';

import '../../../utils/dialog_utils.dart';
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
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppPalette.primary.withValues(alpha: .25)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppPalette.primary, width: 1.4),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppPalette.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppPalette.primary.withValues(alpha: .15),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppPalette.primary.withValues(alpha: .08),
                AppPalette.surface,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.onSurface.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Recuperar contraseña',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppPalette.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  label:
                      'Campo de correo electronico para recuperar contrasena',
                  hint: 'Ingrese su correo institucional',
                  textField: true,
                  enabled: true,
                  focusable: true,
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Correo electronico',
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: focusedBorder,
                      prefixIcon: Icon(Icons.email, color: AppPalette.primary),
                      isDense: true,
                    ),
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
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Semantics(
                      label: 'Boton para cancelar recuperacion de contrasena',
                      button: true,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppPalette.primary,
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      label:
                          'Boton para enviar correo de recuperacion de contrasena',
                      button: true,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          foregroundColor: AppPalette.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _loading ? null : _enviarCorreo,
                        child: _loading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppPalette.surface,
                                ),
                              )
                            : const Text('Enviar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _enviarCorreo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final email = _emailController.text.trim();
    String mensaje;
    bool envioOk = false;

    try {
      await AuthService().sendPasswordResetEmail(email);
      mensaje = 'Se ha enviado un enlace para restablecer la contrasena.';
      envioOk = true;
    } catch (e) {
      mensaje = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    rootNavigator.pop();

    if (envioOk) {
      if (!mounted) return;
      await DialogUtils.showSuccess(
        context: context,
        title: 'Recuperación de contraseña',
        message: mensaje,
      );
      return;
    }

    if (!mounted) return;
    await DialogUtils.showError(
      context: context,
      title: 'Recuperación de contraseña',
      message: mensaje,
    );
  }
}
