import 'dart:convert';
import 'dart:isolate';

import '../models.dart';
import 'net.dart';

/// Zugriff auf die Xtream-Codes-API (player_api.php).
class XtreamClient {
  XtreamClient(Source source)
      : base = normalizeServer(source.server),
        user = source.user.trim(),
        pass = source.pass.trim(),
        sourceId = source.id;

  final String base;
  final String user;
  final String pass;
  final String sourceId;
  String liveExt = 'ts';

  static String normalizeServer(String server) {
    var s = server.trim();
    for (final marker in ['/player_api.php', '/get.php']) {
      final i = s.indexOf(marker);
      if (i >= 0) s = s.substring(0, i);
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(s)) {
      s = 'http://$s';
    }
    return s;
  }

  String _seg(String v) => Uri.encodeComponent(v)
      .replaceAll('%40', '@')
      .replaceAll('%2B', '+')
      .replaceAll('%21', '!');

  Uri _api([String? action, Map<String, String> extra = const {}]) {
    final q = <String, String>{'username': user, 'password': pass};
    if (action != null) q['action'] = action;
    q.addAll(extra);
    return Uri.parse('$base/player_api.php').replace(queryParameters: q);
  }

  Future<String> _get(Uri uri) async {
    final res = await httpClient
        .get(uri, headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 60));
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const AppException('Zugriff verweigert – Benutzername oder Passwort prüfen.');
    }
    if (res.statusCode != 200) {
      throw AppException('Server antwortet mit Fehler ${res.statusCode}.');
    }
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  Future<AccountInfo> login() async {
    final body = await _get(_api());
    final dynamic data;
    try {
      data = jsonDecode(body);
    } catch (_) {
      throw const AppException('Ungültige Antwort – stimmt die Server-URL?');
    }
    final info = data is Map ? data['user_info'] : null;
    if (info is! Map || info['auth'].toString() != '1') {
      throw const AppException('Anmeldung fehlgeschlagen – Benutzername oder Passwort prüfen.');
    }
    final status = (info['status'] ?? 'Active').toString().toLowerCase();
    if (status.isNotEmpty && status != 'active') {
      throw AppException('Account-Status: ${info['status']}');
    }
    final formats = info['allowed_output_formats'];
    if (formats is List && !formats.contains('ts') && formats.contains('m3u8')) {
      liveExt = 'm3u8';
    }
    final exp = int.tryParse('${info['exp_date']}');
    return AccountInfo(
      expires: (exp != null && exp > 0)
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000)
          : null,
      activeCons: int.tryParse('${info['active_cons']}'),
      maxCons: int.tryParse('${info['max_connections']}'),
    );
  }

  Future<Catalog> catalog(Section section) async {
    final (catAction, streamAction) = switch (section) {
      Section.live => ('get_live_categories', 'get_live_streams'),
      Section.movie => ('get_vod_categories', 'get_vod_streams'),
      Section.series => ('get_series_categories', 'get_series'),
    };
    final results = await Future.wait([
      _get(_api(catAction)),
      _get(_api(streamAction)),
    ]);
    final args = _ParseArgs(
      cats: results[0],
      streams: results[1],
      section: section,
      base: base,
      user: _seg(user),
      pass: _seg(pass),
      sourceId: sourceId,
      liveExt: liveExt,
    );
    return Isolate.run(() => _parseCatalog(args));
  }

  /// Episoden einer Serie, nach Staffel gruppiert.
  Future<Map<int, List<MediaItem>>> episodes(MediaItem series) async {
    final body = await _get(_api('get_series_info', {'series_id': series.seriesId ?? ''}));
    final data = jsonDecode(body);
    dynamic eps = data is Map ? data['episodes'] : null;
    final flat = <Map>[];
    if (eps is Map) {
      for (final v in eps.values) {
        if (v is List) flat.addAll(v.whereType<Map>());
      }
    } else if (eps is List) {
      for (final v in eps) {
        if (v is List) {
          flat.addAll(v.whereType<Map>());
        } else if (v is Map) {
          flat.add(v);
        }
      }
    }
    final u = _seg(user), p = _seg(pass);
    final out = <int, List<MediaItem>>{};
    for (final e in flat) {
      final season = int.tryParse('${e['season']}') ?? 0;
      final num = int.tryParse('${e['episode_num']}') ?? 0;
      final ext = (e['container_extension'] ?? 'mp4').toString();
      final title = (e['title'] ?? 'Episode $num').toString().trim();
      final info = e['info'];
      out.putIfAbsent(season, () => []).add(MediaItem(
            sourceId: sourceId,
            section: Section.series,
            name: title,
            categoryId: series.categoryId,
            url: '$base/series/$u/$p/${e['id']}.$ext',
            logo: info is Map ? info['movie_image']?.toString() : null,
            seriesId: series.seriesId,
            meta: 'S${season.toString().padLeft(2, '0')}E${num.toString().padLeft(2, '0')}',
          ));
    }
    for (final list in out.values) {
      list.sort((a, b) => (a.meta ?? '').compareTo(b.meta ?? ''));
    }
    return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }
}

class _ParseArgs {
  const _ParseArgs({
    required this.cats,
    required this.streams,
    required this.section,
    required this.base,
    required this.user,
    required this.pass,
    required this.sourceId,
    required this.liveExt,
  });
  final String cats, streams, base, user, pass, sourceId, liveExt;
  final Section section;
}

Catalog _parseCatalog(_ParseArgs a) {
  final catsJson = jsonDecode(a.cats);
  final streamsJson = jsonDecode(a.streams);
  final categories = <Category>[
    if (catsJson is List)
      for (final c in catsJson.whereType<Map>())
        Category('${c['category_id']}', (c['category_name'] ?? '?').toString()),
  ];
  final items = <MediaItem>[];
  if (streamsJson is List) {
    for (final s in streamsJson.whereType<Map>()) {
      final name = (s['name'] ?? 'Unbenannt').toString().trim();
      final cat = '${s['category_id']}';
      switch (a.section) {
        case Section.series:
          items.add(MediaItem(
            sourceId: a.sourceId,
            section: Section.series,
            name: name,
            categoryId: cat,
            seriesId: '${s['series_id']}',
            logo: _str(s['cover']),
            meta: _year(s),
          ));
        case Section.movie:
          final ext = (s['container_extension'] ?? 'mp4').toString();
          items.add(MediaItem(
            sourceId: a.sourceId,
            section: Section.movie,
            name: name,
            categoryId: cat,
            url: '${a.base}/movie/${a.user}/${a.pass}/${s['stream_id']}.$ext',
            logo: _str(s['stream_icon']),
            meta: _year(s),
          ));
        case Section.live:
          items.add(MediaItem(
            sourceId: a.sourceId,
            section: Section.live,
            name: name,
            categoryId: cat,
            url: '${a.base}/live/${a.user}/${a.pass}/${s['stream_id']}.${a.liveExt}',
            logo: _str(s['stream_icon']),
          ));
      }
    }
  }
  return Catalog(categories, items);
}

String? _str(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

String? _year(Map s) {
  final y = s['year'] ?? s['releaseDate'] ?? s['release_date'];
  final str = y?.toString() ?? '';
  final m = RegExp(r'(19|20)\d{2}').firstMatch(str);
  return m?.group(0);
}
