import 'dart:convert';
import 'dart:io';

import 'net.dart';

const _repo = 'Baenji/noad-iptv-player';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.downloadUrl, required this.pageUrl});
  final String version;

  /// Direkter Download für diese Plattform (Setup.exe bzw. macOS-Zip).
  final String downloadUrl;

  /// Release-Seite auf GitHub.
  final String pageUrl;
}

/// Fragt das neueste Release auf GitHub ab. `null`, wenn nichts Neueres da ist
/// oder keine Verbindung besteht.
Future<UpdateInfo?> checkForUpdate(String current) async {
  try {
    final res = await httpClient.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'noAd-IPTV-Player'},
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['prerelease'] == true || j['draft'] == true) return null;
    final latest = (j['tag_name'] ?? '').toString().replaceFirst(RegExp('^v'), '');
    if (!isNewerVersion(latest, current)) return null;
    final page = (j['html_url'] ?? 'https://github.com/$_repo/releases/latest').toString();
    var download = page;
    for (final a in (j['assets'] as List? ?? const [])) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      final url = (a['browser_download_url'] ?? '').toString();
      if (Platform.isWindows && name.endsWith('.exe')) download = url;
      if (Platform.isMacOS && name.contains('macos') && name.endsWith('.zip')) download = url;
    }
    return UpdateInfo(version: latest, downloadUrl: download, pageUrl: page);
  } catch (_) {
    return null;
  }
}

/// Vergleicht Versionen wie 0.2.0 und 0.10.1. Vorabversionen (mit „-“) zählen nicht.
bool isNewerVersion(String candidate, String current) {
  if (candidate.contains('-') || candidate.isEmpty) return false;
  List<int> parts(String v) =>
      v.split('-').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final a = parts(candidate), b = parts(current);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}
