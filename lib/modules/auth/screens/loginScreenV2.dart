import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app.dart';
import '../../../config/theme_config.dart';
import '../../../providers/user_provider_V2.dart';
import '../../../utils/color_utils.dart';
import '../../../utils/user_log_service.dart';
import '../../../utils/validators.dart';
import '../services/authServiceV2.dart';
import '../widgets/publicLogoWidget.dart';
import '../widgets/publicTitleWidget.dart';
import '../widgets/reset_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _mostrarDialogo(String titulo, String mensaje) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(titulo),
            content: Text(mensaje),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Aceptar'),
              ),
            ],
          ),
    );
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
      borderSide: BorderSide(color: Colors.red.withOpacity(.25)),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
    );

    return Scaffold(
      backgroundColor:
          parseColor(ThemeProvider.config?.colorFondo) ??
          theme.colorScheme.background,
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
                      // encabezado público
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
                      // tarjeta con degradé y borde
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
                                  color: Colors.red.withOpacity(.15),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.red.withOpacity(.06),
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
                                        // Email
                                        Semantics(
                                          label:
                                              'Campo para correo electrónico',
                                          hint:
                                              'Ingrese su correo institucional',
                                          textField: true,
                                          enabled: true,
                                          focusable: true,
                                          child: TextFormField(
                                            controller: _emailController,
                                            decoration: InputDecoration(
                                              labelText: 'Correo electrónico',
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
                                              if (!Validators.isValidEmail(
                                                value,
                                              )) {
                                                return 'Ingrese un correo válido';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Password
                                        Semantics(
                                          label: 'Campo para contraseña',
                                          hint: 'Ingrese su contraseña',
                                          textField: true,
                                          enabled: true,
                                          focusable: true,
                                          child: TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscure,
                                            decoration: InputDecoration(
                                              labelText: 'Contraseña',
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
                                                        ? 'Mostrar contraseña'
                                                        : 'Ocultar contraseña',
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
                                            validator:
                                                (value) =>
                                                    value == null ||
                                                            value.isEmpty
                                                        ? 'Ingrese su contraseña'
                                                        : null,
                                            onFieldSubmitted:
                                                (_) => _iniciarSesion(),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        // Botón login
                                        Semantics(
                                          label: 'Botón para iniciar sesión',
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
                                              child:
                                                  _loading
                                                      ? const SizedBox(
                                                        height: 22,
                                                        width: 22,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.white),
                                                        ),
                                                      )
                                                      : Text(
                                                        'Iniciar sesión',
                                                        style: TextStyle(
                                                          fontFamily:
                                                              fontGeneral,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Reset password
                                        Semantics(
                                          label:
                                              'Botón para recuperar contraseña',
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
                                              '¿Olvidaste tu contraseña?',
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
                child: Container(color: Colors.redAccent.withOpacity(0.08)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _loading = true);
    try {
      final user = await AuthService().loginWithEmailAndPassword(
        email,
        password,
      );

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

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppRouter()),
        );
        return;
      }

      setState(() => _loading = false);
      _mostrarDialogo('Error al iniciar sesión', 'Respuesta inválida.');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _mostrarDialogo(
          'Error al iniciar sesión',
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}
