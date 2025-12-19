import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../utils/history_types.dart';
import '../view/user_logs_view.dart';
import '../widgets/history_selector_widget.dart';
import '../view/daily_route_view.dart';
import '../view/management_file_view.dart';
import '../view/management_route_view.dart';
import '../view/management_schedule_view.dart';
import '../view/management_user_view.dart';
import '../../../utils/navigation_utils.dart';

class AdminHistoryScreen extends StatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  State<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends State<AdminHistoryScreen> {
  HistoryType? _selected;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('History system'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        leading: const BackToDashboardButton(),
      ),
      body: SafeArea(
        child: Center(child: Text('Disponible solo en la versión web.')),
      ),
    );
  }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('History system'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.redAccent,
        leading: const BackToDashboardButton(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              HistorySelectorWidget(
                selected: _selected,
                onChanged: (value) => setState(() => _selected = value),
              ),
              const SizedBox(height: 24),
              Expanded(child: _renderVista()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _renderVista() {
    switch (_selected) {
      case HistoryType.rutasDiarias:
        return const RutasDiariasView();
      case HistoryType.gestionRutas:
        return const GestionRutasView();
      case HistoryType.gestionUsuarios:
        return const GestionUsuariosView();
      case HistoryType.gestionHorarios:
        return const GestionHorariosView();
      case HistoryType.gestionDocumentos:
        return const GestionDocumentosView();
      case HistoryType.userLogs:
        return const GestionLogsUsuariosView();
      default:
        return const Center(
          child: Text('Selecciona un historial para ver los detalles.'),
        );
    }
  }
}
