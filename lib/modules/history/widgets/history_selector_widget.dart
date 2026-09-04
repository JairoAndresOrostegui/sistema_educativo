import 'package:sistema_educativo/config/app_palette.dart';
import 'package:flutter/material.dart';
import '../utils/history_types.dart';

class HistorySelectorWidget extends StatelessWidget {
  final HistoryType? selected;
  final ValueChanged<HistoryType?> onChanged;

  const HistorySelectorWidget({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Selector de historial',
      child: DropdownButtonFormField<HistoryType>(
        initialValue: selected,
        items: HistoryType.values
            .map(
              (type) => DropdownMenuItem(value: type, child: Text(type.label)),
            )
            .toList(),
        decoration: InputDecoration(
          labelText: 'Selecciona un historial',
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppPalette.primary.withValues(alpha: .8),
            ),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
