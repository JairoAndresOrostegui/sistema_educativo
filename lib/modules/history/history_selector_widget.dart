import 'package:flutter/material.dart';

import '../../utils/history_types.dart';

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
        value: selected,
        items: HistoryType.values.map((type) {
          return DropdownMenuItem(
            value: type,
            child: Text(type.label),
          );
        }).toList(),
        decoration: const InputDecoration(
          labelText: 'Selecciona un historial',
          border: OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
