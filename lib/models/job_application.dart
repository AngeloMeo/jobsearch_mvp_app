class JobApplication {
  final String id;
  final String jobId;
  final String nome;
  final String cognome;
  final String email;
  final String cvFileName;
  final String dataInvio;
  final String? cvPath;
  final String? cvUrl;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.nome,
    required this.cognome,
    required this.email,
    required this.cvFileName,
    required this.dataInvio,
    this.cvPath,
    this.cvUrl,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    return JobApplication(
      id: json['id'] as String? ?? '',
      jobId: json['jobId'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      cognome: json['cognome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      cvFileName: json['cvFileName'] as String? ?? '',
      dataInvio: json['dataInvio'] as String? ?? '',
      cvPath: json['cvPath'] as String?,
      cvUrl: json['cvUrl'] as String?,
    );
  }

  String get fullName => '$nome $cognome'.trim();

  String get formattedDate {
    final parsed = DateTime.tryParse(dataInvio)?.toLocal();
    if (parsed == null) return dataInvio;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/$year • $hour:$minute';
  }
}
