import 'package:flutter/material.dart';

import '../../../utils/navigation_utils.dart';
import '../widgets/academic_groups_admin_panel.dart';
import '../widgets/academic_years_admin_panel.dart';

class AdminParametersScreen extends StatelessWidget {
  const AdminParametersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración académica'),
        centerTitle: true,
        leading: const BackToDashboardButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: colors.surfaceContainerLow,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Administra los años lectivos y los grupos de la sede. '
                  'Los catálogos internos del sistema no se modifican desde '
                  'esta pantalla.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const AcademicYearsAdminPanel(),
            const SizedBox(height: 16),
            const AcademicGroupsAdminPanel(),
          ],
        ),
      ),
    );
  }
}
