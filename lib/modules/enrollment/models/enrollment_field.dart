class EnrollmentField {
  final String name;
  final String label;
  final String type; // string, int, date, datetime, bool, enum, text
  final bool required;
  final List<String> editableBy;
  final String? defaultValue;
  final String? formula;
  final List<String>? options;
  final String? optionsSource;

  const EnrollmentField({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    required this.editableBy,
    this.defaultValue,
    this.formula,
    this.options,
    this.optionsSource,
  });

  bool editableForRole(String role) =>
      editableBy.contains(role) || editableBy.contains('system');
}
