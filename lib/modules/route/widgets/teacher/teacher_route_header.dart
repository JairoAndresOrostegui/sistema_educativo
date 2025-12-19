import 'package:flutter/material.dart';

import '../../../../models/route/route_model.dart';

class TeacherRouteHeader extends StatelessWidget {
  final List<RouteModel> routes;
  final RouteModel? selected;
  final ValueChanged<RouteModel?> onRouteChanged;
  final bool showGrouping;
  final bool groupSameAddress;
  final ValueChanged<bool> onToggleGrouping;

  const TeacherRouteHeader({
    super.key,
    required this.routes,
    required this.selected,
    required this.onRouteChanged,
    required this.showGrouping,
    required this.groupSameAddress,
    required this.onToggleGrouping,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<RouteModel>(
          decoration: const InputDecoration(
            labelText: 'Selecciona una ruta',
            border: OutlineInputBorder(),
          ),
          initialValue: selected,
          items:
              routes
                  .map(
                    (r) => DropdownMenuItem<RouteModel>(
                      value: r,
                      child: Text(r.name),
                    ),
                  )
                  .toList(),
          onChanged: onRouteChanged,
        ),
        const SizedBox(height: 12),
        if (showGrouping)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: .15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Agrupar por misma dirección (solo notificaciones de aviso)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Switch.adaptive(
                  value: groupSameAddress,
                  onChanged: onToggleGrouping,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
