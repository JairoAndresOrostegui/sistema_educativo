import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme_config.dart';
import '../../../providers/user_provider_v2.dart';
import '../../../utils/dialog_utils.dart';
import '../services/auth_service_v2.dart';

class DashboardLayout extends StatefulWidget {
  final List<MenuItemData> menuItems;
  const DashboardLayout({super.key, required this.menuItems});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  // URL de la polÃ­tica
  static const String _privacyUrl =
      'https://liceobilinguerodolfollinas.edu.co/';

  Future<void> openPrivacy() async {
    final uri = Uri.parse(_privacyUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        await DialogUtils.showError(
          context: context,
          title: 'No se pudo abrir',
          message: 'No se pudo abrir la polÃ­tica de privacidad.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      await DialogUtils.showError(
        context: context,
        title: 'No se pudo abrir',
        message: 'No se pudo abrir la polÃ­tica de privacidad.',
      );
    }
  }

  String hoveredRoute = '';
  bool hoveringCerrarSesion = false;
  bool hoveringPrivacy = false;

  void _navegar(String ruta) {
    context.go(ruta);
  }

  Future<void> _cerrarSesion() async {
    final userProvider = context.read<UserProviderV2>();
    final user = userProvider.user;

    if (user != null) {
      await AuthService().logout(user);
      userProvider.clearUser();
    } else {
      await FirebaseAuth.instance.signOut();
    }

    if (!mounted) return;
    context.go('/login');
  }

  String _greetingBogota() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos dÃ­as';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Widget _greetingBanner(BuildContext context) {
    final user = context.read<UserProviderV2>().user;
    final fullName =
        user == null ? 'usuario' : '${user.firstName} ${user.lastName}'.trim();
    final school = ThemeProvider.config?.nombre ?? 'tu instituciÃ³n';
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
          border: Border.all(color: Colors.red.withValues(alpha: .15)),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.red.withValues(alpha: .06), Colors.white],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                                        transform: Matrix4.diagonal3Values(
                                          isHovered ? 1.03 : 1.0,
                                          isHovered ? 1.03 : 1.0,
                                          1,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.withValues(alpha: .15),
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.red.withValues(alpha: .06),
                                              Colors.white,
                                            ],
                                          ),
                                          boxShadow:
                                              isHovered
                                                  ? [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.06),
                                                      blurRadius: 12,
                                                      offset: const Offset(
                                                        0,
                                                        6,
                                                      ),
                                                    ),
                                                  ]
                                                  : [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.03),
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
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Icon(
                                                  item.icon,
                                                  size: tileIconSize,
                                                  color: Colors.redAccent,
                                                ),
                                                if (item.badgeCount > 0)
                                                  Positioned(
                                                    right: -6,
                                                    top: -6,
                                                    child: Container(
                                                      padding: const EdgeInsets.all(4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.redAccent,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        '${item.badgeCount}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
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

            // Zona inferior: PRIVACIDAD + CERRAR SESIÃ“N
            SliverFillRemaining(
              hasScrollBody: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ---- BotÃ³n PolÃ­tica de privacidad ----
                      MouseRegion(
                        onEnter: (_) => setState(() => hoveringPrivacy = true),
                        onExit: (_) => setState(() => hoveringPrivacy = false),
                        cursor: SystemMouseCursors.click,
                        child: Semantics(
                          label:
                              'PolÃ­tica de privacidad (se abrirÃ¡ en el navegador)',
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
                              transform: Matrix4.diagonal3Values(
                                hoveringPrivacy ? 1.02 : 1.0,
                                hoveringPrivacy ? 1.02 : 1.0,
                                1,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: .15),
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
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                        : [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
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
                                    'PolÃ­tica de privacidad',
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

                      // ---- BotÃ³n Cerrar sesiÃ³n ----
                      MouseRegion(
                        onEnter:
                            (_) => setState(() => hoveringCerrarSesion = true),
                        onExit:
                            (_) => setState(() => hoveringCerrarSesion = false),
                        cursor: SystemMouseCursors.click,
                        child: Semantics(
                          label: 'Cerrar sesiÃ³n',
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
                                        'Deseas cerrar sesiÃ³n?',
                                      ),
                                      content: const Text(
                                        'Se cerrarÃ¡ tu sesiÃ³n actual.',
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
                                          child: const Text('Cerrar sesiÃ³n'),
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
                              transform: Matrix4.diagonal3Values(
                                hoveringCerrarSesion ? 1.02 : 1.0,
                                hoveringCerrarSesion ? 1.02 : 1.0,
                                1,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: .15),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.red.withValues(alpha: .06),
                                    Colors.white,
                                  ],
                                ),
                              boxShadow:
                                  hoveringCerrarSesion
                                      ? [
                                        BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ]
                                        : [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
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
                                    'Cerrar sesiÃ³n',
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
  final int badgeCount;

  const MenuItemData({
    required this.label,
    required this.icon,
    required this.route,
    this.badgeCount = 0,
  });
}

