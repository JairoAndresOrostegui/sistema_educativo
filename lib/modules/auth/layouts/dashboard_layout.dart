import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme_config.dart';
import '../../../providers/user_provider_V2.dart';
import '../screens/loginScreenV2.dart';
import '../services/authServiceV2.dart';

class DashboardLayout extends StatefulWidget {
  final List<MenuItemData> menuItems;
  const DashboardLayout({super.key, required this.menuItems});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  // URL de la política
  static const String _privacyUrl =
      'https://desarrolloytecnologiasantander.com/privacidad.html';

  Future<void> openPrivacy() async {
    final uri = Uri.parse(_privacyUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir la política de privacidad.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la política de privacidad.'),
        ),
      );
    }
  }

  String hoveredRoute = '';
  bool hoveringCerrarSesion = false;
  bool hoveringPrivacy = false;

  void _navegar(String ruta) {
    Navigator.pushNamed(context, ruta);
  }

  Future<void> _cerrarSesion() async {
    try {
      final userProvider = context.read<UserProviderV2>();
      final user = userProvider.user;

      if (user != null) {
        await AuthService().logout(user);
        userProvider.clearUser();
      } else {
        await FirebaseAuth.instance.signOut();
      }
    } finally {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  String _greetingBogota() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Widget _greetingBanner(BuildContext context) {
    final user = context.read<UserProviderV2>().user;
    final fullName =
        user == null ? 'usuario' : '${user.firstName} ${user.lastName}'.trim();
    final school = ThemeProvider.config?.nombre ?? 'tu institución';
    final greet = _greetingBogota();

    final isWideWeb = kIsWeb || MediaQuery.of(context).size.width >= 900;
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: isWideWeb ? 20 : 16,
      color: Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(.15)),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.red.withOpacity(.06), Colors.white],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Semantics(
          header: true,
          label: '$greet, $fullName, te saluda el sistema del $school',
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: baseStyle,
              children: [
                TextSpan(text: '$greet, '),
                const TextSpan(),
                TextSpan(
                  text: fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.redAccent,
                  ),
                ),
                const TextSpan(text: ', te saluda el sistema de '),
                TextSpan(
                  text: school,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Separador superior + banner
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(child: _greetingBanner(context)),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // GRID dentro de un SliverToBoxAdapter (puedes dejar tu Wrap tal cual)
            SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWeb = kIsWeb;
                  final crossAxisCount = (constraints.maxWidth ~/ 180).clamp(
                    2,
                    isWeb ? 6 : 4,
                  );
                  final bool isMobile = !kIsWeb;
                  final double tileIconSize =
                      isMobile
                          ? (constraints.maxWidth < 380
                              ? 20
                              : constraints.maxWidth < 600
                              ? 24
                              : 28)
                          : 54;

                  return Center(
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: isWeb ? 20 : 14,
                          runSpacing: isWeb ? 24 : 18,
                          alignment: WrapAlignment.center,
                          children:
                              widget.menuItems.map((item) {
                                final isHovered = hoveredRoute == item.route;
                                return MouseRegion(
                                  onEnter:
                                      (_) => setState(
                                        () => hoveredRoute = item.route,
                                      ),
                                  onExit:
                                      (_) => setState(() => hoveredRoute = ''),
                                  cursor: SystemMouseCursors.click,
                                  child: Semantics(
                                    label: item.label,
                                    button: true,
                                    enabled: true,
                                    focusable: true,
                                    child: GestureDetector(
                                      onTap: () => _navegar(item.route),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        curve: Curves.easeOut,
                                        width:
                                            constraints.maxWidth /
                                                crossAxisCount -
                                            18,
                                        padding: const EdgeInsets.all(14),
                                        transform:
                                            Matrix4.identity()
                                              ..scale(isHovered ? 1.03 : 1.0),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withOpacity(.15),
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.red.withOpacity(.06),
                                              Colors.white,
                                            ],
                                          ),
                                          boxShadow:
                                              isHovered
                                                  ? [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.06),
                                                      blurRadius: 12,
                                                      offset: const Offset(
                                                        0,
                                                        6,
                                                      ),
                                                    ),
                                                  ]
                                                  : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.03),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              item.icon,
                                              size: tileIconSize,
                                              color: Colors.redAccent,
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              width: double.infinity,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  item.label,
                                                  textAlign: TextAlign.center,
                                                  softWrap: false,
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        isHovered
                                                            ? FontWeight.w800
                                                            : FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Zona inferior: PRIVACIDAD + CERRAR SESIÓN
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---- Botón Política de privacidad ----
                      MouseRegion(
                        onEnter: (_) => setState(() => hoveringPrivacy = true),
                        onExit: (_) => setState(() => hoveringPrivacy = false),
                        cursor: SystemMouseCursors.click,
                        child: Semantics(
                          label:
                              'Política de privacidad (se abrirá en el navegador)',
                          button: true,
                          enabled: true,
                          focusable: true,
                          child: GestureDetector(
                            onTap: openPrivacy,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              transform:
                                  Matrix4.identity()
                                    ..scale(hoveringPrivacy ? 1.02 : 1.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.red.withOpacity(.15),
                                ),
                                gradient: const LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Color.fromRGBO(244, 67, 54, 0.06),
                                    Colors.white,
                                  ],
                                ),
                                boxShadow:
                                    hoveringPrivacy
                                        ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                        : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.03,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.privacy_tip_outlined,
                                    size: 28,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Política de privacidad',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ---- Botón Cerrar sesión ----
                      MouseRegion(
                        onEnter:
                            (_) => setState(() => hoveringCerrarSesion = true),
                        onExit:
                            (_) => setState(() => hoveringCerrarSesion = false),
                        cursor: SystemMouseCursors.click,
                        child: Semantics(
                          label: 'Cerrar sesión',
                          button: true,
                          enabled: true,
                          focusable: true,
                          child: GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (ctx) => AlertDialog(
                                      title: const Text(
                                        '¿Deseas cerrar sesión?',
                                      ),
                                      content: const Text(
                                        'Se cerrará tu sesión actual.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(ctx, true),
                                          child: const Text('Cerrar sesión'),
                                        ),
                                      ],
                                    ),
                              );
                              if (!mounted) return;
                              if (confirm == true) _cerrarSesion();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              transform:
                                  Matrix4.identity()
                                    ..scale(hoveringCerrarSesion ? 1.02 : 1.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.red.withOpacity(.15),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.red.withOpacity(.06),
                                    Colors.white,
                                  ],
                                ),
                                boxShadow:
                                    hoveringCerrarSesion
                                        ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                        : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.03,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.logout,
                                    size: 28,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Cerrar sesión',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
          ],
        ),
      ),
    );
  }
}

class MenuItemData {
  final String label;
  final IconData icon;
  final String route;

  const MenuItemData({
    required this.label,
    required this.icon,
    required this.route,
  });
}
