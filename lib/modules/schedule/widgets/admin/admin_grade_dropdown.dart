import 'package:flutter/material.dart';

class AdminGradeDropdown extends StatelessWidget {
  final String? selectedGrade;
  final ValueChanged<String?> onChanged;
  final List<String> availableGrades;

  const AdminGradeDropdown({
    super.key,
    required this.selectedGrade,
    required this.onChanged,
    required this.availableGrades,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.red.withValues(alpha: .15)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Colors.red.withValues(alpha: .06), Colors.white],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedGrade,
          hint: const Text('Selecciona un grado'),
          isExpanded: true,
          items:
              availableGrades
                  .map(
                    (String grade) => DropdownMenuItem<String>(
                      value: grade,
                      child: Text(grade),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
