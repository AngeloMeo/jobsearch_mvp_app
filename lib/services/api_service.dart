import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/auth_session.dart';
import '../models/job.dart';
import '../models/job_application.dart';

/// Eccezione applicativa con messaggio pronto per essere mostrato in UI (SnackBar).
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Servizio centrale che gestisce:
/// 1) Storage locale della sessione azienda (SharedPreferences)
/// 2) Tutte le chiamate REST al server locale sulla porta 8080 (package:http)
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  // Chiavi salvate in locale sul telefono tramite SharedPreferences.
  static const String _prefTokenKey = 'auth_token';
  static const String _prefCompanyIdKey = 'company_id';
  static const String _prefCompanyNameKey = 'company_name';

  static const Duration _defaultTimeout = Duration(seconds: 12);
  static const Duration _fileTransferTimeout = Duration(seconds: 30);

  // ===========================================================================
  // 1. STORAGE LOCALE (SharedPreferences) E STATO SESSIONE
  // ===========================================================================

  /// Stato reattivo della sessione: quando cambia (login/logout), la UI si aggiorna da sola.
  final ValueNotifier<AuthSession?> sessionNotifier =
      ValueNotifier<AuthSession?>(null);

  AuthSession? get currentSession => sessionNotifier.value;

  /// Carica IP server e sessione azienda salvati sul dispositivo all'avvio dell'app.
  Future<void> init() async {
    await ApiConfig.init();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefTokenKey);
    final companyId = prefs.getString(_prefCompanyIdKey);
    final companyName = prefs.getString(_prefCompanyNameKey);

    if (token != null &&
        token.isNotEmpty &&
        companyId != null &&
        companyName != null) {
      sessionNotifier.value = AuthSession(
        token: token,
        companyId: companyId,
        nomeAzienda: companyName,
      );
    }
  }

  /// Salva token e dati azienda in SharedPreferences dopo un login riuscito.
  Future<void> _saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefTokenKey, session.token);
    await prefs.setString(_prefCompanyIdKey, session.companyId);
    await prefs.setString(_prefCompanyNameKey, session.nomeAzienda);
    sessionNotifier.value = session;
  }

  /// Cancella il token locale (usato al logout o se la sessione scade).
  Future<void> clearLocalSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefTokenKey);
    await prefs.remove(_prefCompanyIdKey);
    await prefs.remove(_prefCompanyNameKey);
    sessionNotifier.value = null;
  }

  // ===========================================================================
  // 2. ENDPOINT PUBBLICI E AUTENTICAZIONE (JSON su HTTP)
  // ===========================================================================

  /// GET /jobs -> Restituisce tutti gli annunci pubblici per la bacheca.
  Future<List<Job>> fetchPublicJobs() async {
    final decoded = await _performJsonRequest(
      () => http
          .get(_buildUri('/jobs'), headers: _jsonHeaders())
          .timeout(_defaultTimeout),
    );
    if (decoded is! List) {
      throw const ApiException('Formato risposta non valido dal server.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Job.fromJson)
        .toList();
  }

  /// POST /auth/register -> Registra una nuova azienda con nome, email e password.
  Future<void> registerCompany({
    required String nomeAzienda,
    required String email,
    required String password,
  }) async {
    await _performJsonRequest(
      () => http
          .post(
            _buildUri('/auth/register'),
            headers: _jsonHeaders(),
            body: jsonEncode({
              'nomeAzienda': nomeAzienda.trim(),
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(_defaultTimeout),
    );
  }

  /// POST /auth/login -> Autentica l'azienda, riceve il token e lo salva in locale.
  Future<AuthSession> loginCompany({
    required String email,
    required String password,
  }) async {
    final decoded = await _performJsonRequest(
      () => http
          .post(
            _buildUri('/auth/login'),
            headers: _jsonHeaders(),
            body: jsonEncode({
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(_defaultTimeout),
    );

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Risposta di login non valida.');
    }

    final session = AuthSession.fromJson(decoded);
    if (session.token.isEmpty) {
      throw const ApiException('Token di sessione mancante nella risposta.');
    }
    await _saveSession(session);
    return session;
  }

  /// POST /auth/logout -> Invalida il token sul server e pulisce SharedPreferences.
  Future<void> logoutCompany() async {
    final token = currentSession?.token;
    try {
      if (token != null && token.isNotEmpty) {
        await _performJsonRequest(
          () => http
              .post(
                _buildUri('/auth/logout'),
                headers: _jsonHeaders(token: token),
              )
              .timeout(_defaultTimeout),
        );
      }
    } on ApiException catch (e) {
      // Se il server risponde 401 (es. token già scaduto), puliamo comunque il device.
      if (!e.isUnauthorized) {
        await clearLocalSession();
        rethrow;
      }
    } catch (_) {
      await clearLocalSession();
      rethrow;
    }
    await clearLocalSession();
  }

  // ===========================================================================
  // 3. AREA RISERVATA AZIENDA (richiede header Authorization: Bearer <token>)
  // ===========================================================================

  /// GET /company/jobs -> Elenco degli annunci pubblicati dall'azienda loggata.
  Future<List<Job>> fetchCompanyJobs() async {
    final token = _requireToken();
    final decoded = await _performJsonRequest(
      () => http
          .get(
            _buildUri('/company/jobs'),
            headers: _jsonHeaders(token: token),
          )
          .timeout(_defaultTimeout),
    );

    if (decoded is! List) {
      throw const ApiException('Formato risposta non valido dal server.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Job.fromJson)
        .toList();
  }

  /// POST /jobs -> Pubblica un nuovo annuncio associato all'azienda loggata.
  Future<Job> createJob({
    required String titolo,
    required String descrizione,
  }) async {
    final token = _requireToken();
    final decoded = await _performJsonRequest(
      () => http
          .post(
            _buildUri('/jobs'),
            headers: _jsonHeaders(token: token),
            body: jsonEncode({
              'titolo': titolo.trim(),
              'descrizione': descrizione.trim(),
            }),
          )
          .timeout(_defaultTimeout),
    );

    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Formato risposta annuncio non valido.');
    }
    return Job.fromJson(decoded);
  }

  /// `GET /jobs/<jobId>/applications` -> Candidature ricevute per uno specifico annuncio.
  Future<List<JobApplication>> fetchJobApplications(String jobId) async {
    final token = _requireToken();
    final decoded = await _performJsonRequest(
      () => http
          .get(
            _buildUri('/jobs/$jobId/applications'),
            headers: _jsonHeaders(token: token),
          )
          .timeout(_defaultTimeout),
    );

    if (decoded is! List) {
      throw const ApiException('Formato risposta candidature non valido.');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(JobApplication.fromJson)
        .toList();
  }

  // ===========================================================================
  // 4. UPLOAD MULTIPART CV E APERTURA PDF DAL SERVER
  // ===========================================================================

  /// `POST /jobs/<jobId>/apply` -> Invia dati candidato + file CV PDF via MultipartRequest.
  Future<JobApplication> applyToJob({
    required String jobId,
    required String nome,
    required String cognome,
    required String email,
    required PlatformFile cvFile,
  }) async {
    try {
      final request =
          http.MultipartRequest('POST', _buildUri('/jobs/$jobId/apply'));

      // Campi testuali del form multipart.
      request.fields['nome'] = nome.trim();
      request.fields['cognome'] = cognome.trim();
      request.fields['email'] = email.trim();

      // Lettura byte del PDF scelto dal telefono e allegato nel campo "cv".
      final bytes = await cvFile.readAsBytes();
      if (bytes.isEmpty) {
        throw const ApiException('Il file CV selezionato è vuoto o illeggibile.');
      }

      final fileName = cvFile.name.toLowerCase().endsWith('.pdf')
          ? cvFile.name
          : '${cvFile.name}.pdf';

      request.files.add(
        http.MultipartFile.fromBytes('cv', bytes, filename: fileName),
      );

      final streamedResponse =
          await request.send().timeout(_fileTransferTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final decoded = _handleResponse(response);

      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('Risposta candidatura non valida dal server.');
      }
      return JobApplication.fromJson(decoded);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException(_unreachableServerMessage());
    } on TimeoutException {
      throw ApiException(
        'Timeout durante l\'invio della candidatura a ${ApiConfig.currentBaseUrl}.',
      );
    } on http.ClientException catch (e) {
      throw ApiException('Errore di rete durante l\'invio: ${e.message}');
    } catch (e) {
      throw ApiException('Errore imprevisto durante l\'invio: $e');
    }
  }

  /// `GET /uploads/<fileName>` -> Scarica il PDF in cache temporanea e lo apre sul telefono.
  Future<void> openCvPdf(String fileName) async {
    if (fileName.trim().isEmpty) {
      throw const ApiException('Nome file CV non disponibile.');
    }

    final encodedName = Uri.encodeComponent(fileName.trim());
    final uri = _buildUri('/uploads/$encodedName');

    try {
      final response = await http.get(uri).timeout(_fileTransferTimeout);

      if (response.statusCode >= 400) {
        final message = _extractErrorMessage(response) ??
            'Impossibile scaricare il CV (HTTP ${response.statusCode}).';
        throw ApiException(message, statusCode: response.statusCode);
      }

      if (response.bodyBytes.isEmpty) {
        throw const ApiException('Il file PDF scaricato è vuoto.');
      }

      // Salva temporaneamente il file sul dispositivo per aprirlo con un lettore PDF.
      final tempDir = await getTemporaryDirectory();
      final sanitized = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final pdfName =
          sanitized.toLowerCase().endsWith('.pdf') ? sanitized : '$sanitized.pdf';
      final localFile = File('${tempDir.path}/$pdfName');
      await localFile.writeAsBytes(response.bodyBytes, flush: true);

      final result =
          await OpenFilex.open(localFile.path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        throw ApiException(
          result.message.isNotEmpty
              ? 'Impossibile aprire il PDF: ${result.message}'
              : 'Nessuna app trovata per aprire i file PDF.',
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException(_unreachableServerMessage());
    } on TimeoutException {
      throw ApiException(
        'Timeout durante il download del CV da ${ApiConfig.currentBaseUrl}.',
      );
    } on http.ClientException catch (e) {
      throw ApiException('Errore di rete durante il download: ${e.message}');
    } catch (e) {
      throw ApiException('Errore durante l\'apertura del CV: $e');
    }
  }

  // ===========================================================================
  // 5. HELPER HTTP E GESTIONE ERRORI
  // ===========================================================================

  Uri _buildUri(String path) => Uri.parse('${ApiConfig.currentBaseUrl}$path');

  Map<String, String> _jsonHeaders({String? token}) {
    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _requireToken() {
    final token = currentSession?.token;
    if (token == null || token.isEmpty) {
      throw const ApiException(
        'Sessione non valida. Effettua nuovamente il login.',
        statusCode: 401,
      );
    }
    return token;
  }

  /// Esegue la chiamata HTTP e converte errori di rete/timeout in ApiException leggibili.
  Future<dynamic> _performJsonRequest(
    Future<http.Response> Function() requestFn,
  ) async {
    try {
      final response = await requestFn();
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw ApiException(_unreachableServerMessage());
    } on TimeoutException {
      throw ApiException(
        'Timeout di connessione verso ${ApiConfig.currentBaseUrl}. Verifica che il server sia attivo.',
      );
    } on http.ClientException catch (e) {
      throw ApiException('Errore di connessione: ${e.message}');
    } on FormatException {
      throw const ApiException('Risposta non valida dal server.');
    }
  }

  /// Decodifica il JSON se HTTP 2xx, altrimenti estrae il messaggio d'errore del server.
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.trim().isEmpty) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    final serverError = _extractErrorMessage(response);
    throw ApiException(
      serverError ?? 'Errore del server (codice $statusCode).',
      statusCode: statusCode,
    );
  }

  String? _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'] ?? decoded['message'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } catch (_) {
      // Risposta non in formato JSON.
    }
    return null;
  }

  String _unreachableServerMessage() {
    return 'Server non raggiungibile (${ApiConfig.currentBaseUrl}). '
        'Controlla l\'IP dalle Impostazioni e verifica che il server locale sia avviato.';
  }
}
