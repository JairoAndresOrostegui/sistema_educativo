class Validators {
  static bool isValidEmail(String email) {
    final value = email.trim();
    if (value.length > 254 || value.contains('..')) return false;
    final atIndex = value.indexOf('@');
    if (atIndex <= 0 || atIndex != value.lastIndexOf('@')) return false;
    final localPart = value.substring(0, atIndex);
    if (localPart.length > 64 ||
        localPart.startsWith('.') ||
        localPart.endsWith('.')) {
      return false;
    }
    final emailRegex = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
      r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
      r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
    );
    return emailRegex.hasMatch(value);
  }

  static bool isInstitutionalEmail(String email, String domain) {
    final value = email.trim().toLowerCase();
    return value.endsWith('@${domain.toLowerCase()}');
  }
}
