class Job {
  final String id;
  final String companyId;
  final String nomeAzienda;
  final String titolo;
  final String descrizione;
  final String dataPubblicazione;

  const Job({
    required this.id,
    required this.companyId,
    required this.nomeAzienda,
    required this.titolo,
    required this.descrizione,
    required this.dataPubblicazione,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      nomeAzienda: json['nomeAzienda'] as String? ?? 'Azienda',
      titolo: json['titolo'] as String? ?? '',
      descrizione: json['descrizione'] as String? ?? '',
      dataPubblicazione: json['dataPubblicazione'] as String? ?? '',
    );
  }

  String get formattedDate {
    final parsed = DateTime.tryParse(dataPubblicazione)?.toLocal();
    if (parsed == null) return dataPubblicazione;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/$year • $hour:$minute';
  }
}
