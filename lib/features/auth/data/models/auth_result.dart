class AuthResult {
  final bool isSuccess;
  final String message;

  const AuthResult({required this.isSuccess, required this.message});

  factory AuthResult.success([String message = "Success"]) {
    return AuthResult(isSuccess: true, message: message);
  }

  factory AuthResult.failure(String message) {
    return AuthResult(isSuccess: false, message: message);
  }
}
