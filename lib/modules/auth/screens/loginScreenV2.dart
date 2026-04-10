// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme_config.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/color_utils.dart';
import '../../../utils/user_log_service.dart';
import '../../../utils/validators.dart';
import '../../../utils/dialog_utils.dart';
import '../services/auth_service_v2.dart';
import '../widgets/public_logo_widget.dart';
import '../widgets/public_title_widget.dart';
import '../widgets/reset_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final labelColor =
        parseColor(ThemeProvider.config?.colorLabel) ??
        theme.colorScheme.primary;
    final fontGeneral = ThemeProvider.config?.fuenteGeneral;

    // estilos consistentes
    final containerRadius = BorderRadius.circular(16);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.red.withValues(alpha: .25)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
    );

    return Scaffold(
      backgroundColor:
          parseColor(ThemeProvider.config?.colorFondo) ??
          theme.colorScheme.surface,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // encabezado publico
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          PublicTitleWidget(),
                          SizedBox(height: 12),
                          PublicLogoWidget(heightFactor: 0.2),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // tarjeta con degrade y borde
                      Expanded(
                        child: Align(
                          alignment: const Alignment(0, -0.60),
                          child: SizedBox(
                            width: isMobile ? double.infinity : 520,
                            child: Container(
                              margin: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: containerRadius,
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: .15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.red.withValues(alpha: .06),
                                    Colors.white,
                                  ],
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Correo o documento
                                        Semantics(
                                          label:
                                              'Campo para correo institucional o documento',
                                          hint:
                                              'Ingrese su correo institucional o, si es estudiante, su documento',
                                          textField: true,
                                          enabled: true,
                                          focusable: true,
                                          child: TextFormField(
                                            controller: _identifierController,
                                            decoration: InputDecoration(
                                              labelText: 'Correo o documento',
                                              labelStyle: TextStyle(
                                                color: labelColor,
                                                fontFamily: fontGeneral,
                                              ),
                                              border: inputBorder,
                                              enabledBorder: inputBorder,
                                              focusedBorder: focusedBorder,
                                              prefixIcon: const Icon(
                                                Icons.email,
                                                color: Colors.redAccent,
                                              ),
                                              isDense: true,
                                            ),
                                            style: TextStyle(
                                              fontFamily: fontGeneral,
                                            ),
                                            textInputAction:
                                                TextInputAction.next,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Este campo es obligatorio';
                                              }
                                              final trimmed = value.trim();
                                              final isEmail = Validators.isValidEmail(
                                                trimmed,
                                              );
                                              final isDocument =
                                                  RegExp(r'^[0-9]{6,}$').hasMatch(
                                                    trimmed,
                                                  );
                                              if (!isEmail && !isDocument) {
                                                return 'Ingrese un correo valido o un documento numerico';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Password
                                        Semantics(
                                          label: 'Campo para contrasena',
                                          hint: 'Ingrese su contrasena',
                                          textField: true,
                                          enabled: true,
                                          focusable: true,
                                          child: TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscure,
                                            decoration: InputDecoration(
                                              labelText: 'Contrasena',
                                              labelStyle: TextStyle(
                                                color: labelColor,
                                                fontFamily: fontGeneral,
                                              ),
                                              border: inputBorder,
                                              enabledBorder: inputBorder,
                                              focusedBorder: focusedBorder,
                                              prefixIcon: const Icon(
                                                Icons.lock,
                                                color: Colors.redAccent,
                                              ),
                                              suffixIcon: Semantics(
                                                label:
                                                    _obscure
                                                        ? 'Mostrar contrasena'
                                                        : 'Ocultar contrasena',
                                                button: true,
                                                child: IconButton(
                                                  icon: Icon(
                                                    _obscure
                                                        ? Icons.visibility
                                                        : Icons.visibility_off,
                                                  ),
                                                  onPressed:
                                                      () => setState(
                                                        () =>
                                                            _obscure =
                                                                !_obscure,
                                                      ),
                                                ),
                                              ),
                                              isDense: true,
                                            ),
                                            style: TextStyle(
                                              fontFamily: fontGeneral,
                                            ),
                                            textInputAction:
                                                TextInputAction.done,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Ingrese su contrasena';
                                              }
                                              if (value.length < 8) {
                                                return 'Minimo 8 caracteres';
                                              }
                                              return null;
                                            },
                                            onFieldSubmitted:
                                                (_) => _iniciarSesion(),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        // Boton login
                                        Semantics(
                                          label: 'Boton para iniciar sesión',
                                          button: true,
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                minimumSize:
                                                    const Size.fromHeight(48),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                              onPressed:
                                                  _loading
                                                      ? null
                                                      : _iniciarSesion,
                                              child: Text(
                                                'Iniciar sesión',
                                                style: TextStyle(
                                                  fontFamily: fontGeneral,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Reset password
                                        Semantics(
                                          label:
                                              'Boton para recuperar contrasena',
                                          button: true,
                                          child: TextButton(
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder:
                                                    (_) =>
                                                        const ResetPasswordDialog(),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.redAccent,
                                            ),
                                            child: Text(
                                              '¿Olvidaste tu contrasena?',
                                              style: TextStyle(
                                                fontFamily: fontGeneral,
                                              ),
                                            ),
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
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_loading)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                ),
              ),
            ),
          if (_loading)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.8)),
            ),
        ],
      ),
    );
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _loading = true);
    try {
      final user = await AuthService().loginWithEmailAndPassword(
        identifier,
        password,
      );

      if (!mounted) return;

      if (user != null) {
        final userProvider = Provider.of<UserProviderV2>(
          context,
          listen: false,
        );
        userProvider.setUser(user);

        try {
          await UserLogService().logEvent(user: user, event: 'login');
        } catch (_) {
          // no rompe UX si falla el log
        }

        // pantalla correspondiente segun rol cuando el provider cambia.
        return;
      }

      setState(() => _loading = false);
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'Error al iniciar sesión',
        message: 'Respuesta invalida.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      await DialogUtils.showError(
        context: context,
        title: 'Error al iniciar sesión',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}
