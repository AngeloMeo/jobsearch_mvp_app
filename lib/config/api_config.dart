import 'package:shared_preferences/shared_preferences.dart';

/// Gestisce l'indirizzo del server REST locale (default + override salvato in locale).
class ApiConfig {
  /// IP predefinito del PC su cui gira il server REST (porta 8080).
  static const String baseUrl = 'http://192.168.178.72:8080';

  // Chiave usata in SharedPreferences per ricordare l'IP inserito dall'utente.
  static const String _prefServerBaseUrlKey = 'server_base_url';

  static String _activeBaseUrl = baseUrl;

  /// URL attualmente usato da tutte le chiamate HTTP dell'app.
  static String get currentBaseUrl => _activeBaseUrl;

  /// All'avvio dell'app legge da SharedPreferences l'eventuale IP personalizzato.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefServerBaseUrlKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _activeBaseUrl = saved.trim();
    } else {
      _activeBaseUrl = baseUrl;
    }
  }

  /// Salva un nuovo IP/URL su SharedPreferences così resta valido anche al riavvio.
  static Future<String> saveServerAddress(String rawInput) async {
    final normalized = normalizeServerUrl(rawInput);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefServerBaseUrlKey, normalized);
    _activeBaseUrl = normalized;
    return normalized;
  }

  /// Converte un input breve (es. "192.168.1.45") nell'URL completo "http://192.168.1.45:8080".
  static String normalizeServerUrl(String rawInput) {
    var value = rawInput.trim();
    if (value.isEmpty) {
      throw const FormatException('Inserisci un indirizzo IP o URL valido.');
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      throw const FormatException('Indirizzo server non valido.');
    }

    final port = uri.hasPort ? uri.port : 8080;
    return '${uri.scheme}://${uri.host}:$port';
  }
}
