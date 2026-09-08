import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../services/auth_service_v2.dart';
import '../utils/auth_access_policy.dart';

class ChangeTemporaryPasswordScreen extends StatefulWidget {
  const ChangeTemporaryPasswordScreen({super.key});

  @override
  State<ChangeTemporaryPasswordScreen> createState() =>
      _ChangeTemporaryPasswordScreenState();
}

class _ChangeTemporaryPasswordScreenState
    extends State<ChangeTemporaryPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;
  bool _hidden = true;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value ?? '';
    if (text.length < 10 ||
        !RegExp('[a-z]').hasMatch(text) ||
        !RegExp('[A-Z]').hasMatch(text) ||
        !RegExp('[0-9]').hasMatch(text) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(text)) {
      return 'Usa 10 caracteres, mayúscula, minúscula, número y símbolo.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirmation.text) {
      await DialogUtils.showError(
        context: context,
        title: 'Las contraseñas no coinciden',
        message: 'Escribe exactamente la misma contraseña en ambos campos.',
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService().changeTemporaryStudentPassword(_password.text);
      if (!mounted) return;
      final provider = context.read<UserProviderV2>();
      final current = provider.user!;
      provider.setUser(current.copyWith(mustChangePassword: false));
      context.go(AuthAccessPolicy.homeForRole(current.role));
    } on TemporaryPasswordChangedSessionException catch (error) {
      if (!mounted) return;
      context.read<UserProviderV2>().clearUser();
      await DialogUtils.showInfo(
        context: context,
        title: 'Contraseña cambiada',
        message: error.toString(),
      );
      if (mounted) context.go('/login');
    } catch (error) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'No se pudo cambiar la contraseña',
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crear contraseña personal')),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.lock_reset, size: 52),
                      const SizedBox(height: 16),
                      const Text(
                        'La clave entregada por el colegio es temporal. Crea una que solo tú conozcas antes de continuar.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidden,
                        validator: _validate,
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _hidden = !_hidden),
                            icon: Icon(
                              _hidden ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: _hidden,
                        validator: _validate,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contraseña',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _loading ? null : _save,
                        child: Text(
                          _loading ? 'Guardando…' : 'Guardar y continuar',
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
    ),
  );
}
