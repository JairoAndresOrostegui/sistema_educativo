class SubmitResult {
  final bool success;
  final String? estado;
  final Map<String, String> payload;
  final String? error;

  const SubmitResult({
    required this.success,
    required this.payload,
    this.estado,
    this.error,
  });
}
