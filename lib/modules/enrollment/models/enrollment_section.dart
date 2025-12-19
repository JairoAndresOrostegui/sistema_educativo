import 'enrollment_field.dart';

class EnrollmentSection {
  final String title;
  final List<String> fieldNames;

  const EnrollmentSection({
    required this.title,
    required this.fieldNames,
  });

  Iterable<EnrollmentField> fieldsFrom(Iterable<EnrollmentField> all) {
    final nameSet = fieldNames.toSet();
    return all.where((f) => nameSet.contains(f.name));
  }
}
