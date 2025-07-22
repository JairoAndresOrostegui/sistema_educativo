import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../auth/pages/login_page.dart';

class DashboardLayout extends StatefulWidget {
  final List<MenuItemData> menuItems;
  const DashboardLayout({super.key, required this.menuItems});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  String hoveredRoute = '';
  bool hoveringCerrarSesion = false;

  void _navegar(String ruta) {
    Navigator.pushNamed(context, ruta);
  }

  void _cerrarSesion() {
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            Image.asset('assets/logo.jpg', height: 100),
            const SizedBox(height: 20),
            const Text(
              'Liceo Bilingüe Rodolfo Llinás',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWeb = kIsWeb;
                  int crossAxisCount = (constraints.maxWidth ~/ 140).clamp(2, isWeb ? 6 : 4);

                  return Center(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: isWeb ? 20 : 16,
                        runSpacing: isWeb ? 30 : 24,
                        alignment: WrapAlignment.center,
                        children: widget.menuItems.map((item) {
                          final isHovered = hoveredRoute == item.route;

                          return MouseRegion(
                            onEnter: (_) => setState(() => hoveredRoute = item.route),
                            onExit: (_) => setState(() => hoveredRoute = ''),
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _navegar(item.route),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: constraints.maxWidth / crossAxisCount - 20,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isHovered ? const Color.fromRGBO(240, 240, 240, 1) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: isHovered
                                      ? [
                                          const BoxShadow(
                                            color: Color.fromRGBO(0, 0, 0, 0.1),
                                            blurRadius: 8,
                                            offset: Offset(0, 4),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(item.icon, size: 48, color: const Color.fromARGB(255, 31, 155, 212)),
                                    const SizedBox(height: 10),
                                    Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
                                        color: isHovered ? Colors.black : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: MouseRegion(
                onEnter: (_) => setState(() => hoveringCerrarSesion = true),
                onExit: (_) => setState(() => hoveringCerrarSesion = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _cerrarSesion,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: hoveringCerrarSesion ? const Color.fromRGBO(240, 240, 240, 1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: hoveringCerrarSesion
                          ? [
                              const BoxShadow(
                                color: Color.fromRGBO(0, 0, 0, 0.1),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.logout, size: 36, color: Colors.redAccent),
                        SizedBox(height: 8),
                        Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
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
    );
  }
}

class MenuItemData {
  final String label;
  final IconData icon;
  final String route;

  const MenuItemData({required this.label, required this.icon, required this.route});
}
