class EnrollmentRule {
  final String fieldName;
  final List<String> roles;
  final List<String> estados;
  final bool? visible;
  final bool? editable;
  final bool? required;

  const EnrollmentRule({
    required this.fieldName,
    this.roles = const [],
    this.estados = const [],
    this.visible,
    this.editable,
    this.required,
  });

  bool matches({required String role, required String estado}) {
    final roleOk = roles.isEmpty || roles.contains(role);
    final estadoOk = estados.isEmpty || estados.contains(estado);
    return roleOk && estadoOk;
  }
}
