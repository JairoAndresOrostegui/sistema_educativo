import '../models/enrollment_field.dart';
import '../models/enrollment_rule.dart';

class EnrollmentRulesService {
  final List<EnrollmentRule> rules;

  EnrollmentRulesService({required this.rules});

  bool isVisible({
    required EnrollmentField field,
    required String role,
    required String estado,
  }) {
    final matches = rules.where((r) => r.fieldName == field.name);
    for (final rule in matches) {
      if (rule.matches(role: role, estado: estado)) {
        return rule.visible ?? true;
      }
    }
    return true;
  }

  bool isEditable({
    required EnrollmentField field,
    required String role,
    required String estado,
    required bool isAdmin,
  }) {
    if (isAdmin) return true;
    final matches = rules.where((r) => r.fieldName == field.name);
    for (final rule in matches) {
      if (rule.matches(role: role, estado: estado)) {
        return rule.editable ?? field.editableBy.contains(role);
      }
    }
    return field.editableBy.contains(role);
  }

  bool isRequired({
    required EnrollmentField field,
    required String role,
    required String estado,
  }) {
    final matches = rules.where((r) => r.fieldName == field.name);
    for (final rule in matches) {
      if (rule.matches(role: role, estado: estado)) {
        return rule.required ?? field.required;
      }
    }
    return field.required;
  }
}
