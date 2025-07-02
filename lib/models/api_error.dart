class ApiError implements Exception {
  final String status;
  final String code;
  final String message;
  final Map<String, dynamic>? details;

  ApiError({
    required this.status,
    required this.code,
    required this.message,
    this.details,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      status: json['status'] ?? 'error',
      code: json['code'] ?? json['error_code'] ?? 'UNKNOWN_ERROR',
      message: json['message'] ?? json['error'] ?? 'Une erreur est survenue',
      details: json['details'],
    );
  }

  @override
  String toString() => 'ApiError: $message (Code: $code)';
}