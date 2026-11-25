class AuthSession {
  final String token;
  final String companyId;
  final String nomeAzienda;

  const AuthSession({
    required this.token,
    required this.companyId,
    required this.nomeAzienda,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      nomeAzienda: json['nomeAzienda'] as String? ?? '',
    );
  }
}
