class Validators {
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$",
    );
    return emailRegex.hasMatch(email.trim());
  }

  static bool isInstitutionalEmail(String email, String domain) {
    final value = email.trim().toLowerCase();
    return value.endsWith('@${domain.toLowerCase()}');
  }
}
