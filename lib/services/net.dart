import 'package:http/http.dart' as http;

/// Viele IPTV-Server erwarten einen Player-User-Agent.
const userAgent = 'VLC/3.0.20 LibVLC/3.0.20';

final http.Client httpClient = http.Client();

/// Fehler mit einer Meldung, die direkt angezeigt werden kann.
class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

String friendlyError(Object e) {
  if (e is AppException) return e.message;
  final s = e.toString();
  if (s.contains('TimeoutException')) {
    return 'Zeitüberschreitung – der Server antwortet nicht.';
  }
  if (s.contains('SocketException') || s.contains('ClientException')) {
    return 'Server nicht erreichbar – Adresse und Internetverbindung prüfen.';
  }
  if (s.contains('FormatException')) {
    return 'Ungültige Antwort vom Server.';
  }
  return s;
}
