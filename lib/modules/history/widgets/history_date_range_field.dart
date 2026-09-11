import 'package:flutter/material.dart';

class HistoryDateRangeField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const HistoryDateRangeField({
    super.key,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: value.isEmpty ? 'Seleccionar rango de fechas' : 'Rango $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Rango de fechas',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.date_range),
          ),
          child: Text(value.isEmpty ? 'Seleccionar' : value),
        ),
      ),
    );
  }
}
