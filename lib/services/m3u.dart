import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import '../models.dart';
import 'net.dart';

/// Lädt eine M3U-Playlist (URL oder Datei) und teilt sie in Live/Filme/Serien.
Future<Map<Section, Catalog>> loadM3u(Source source) async {
  List<int> bytes;
  if (source.type == SourceType.m3uFile) {
    final f = File(source.path);
    if (!await f.exists()) {
      throw AppException('Datei nicht gefunden: ${source.path}');
    }
    bytes = await f.readAsBytes();
  } else {
    final res = await httpClient
        .get(Uri.parse(source.url.trim()), headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) {
      throw AppException('Playlist konnte nicht geladen werden (Fehler ${res.statusCode}).');
    }
    bytes = res.bodyBytes;
  }
  final id = source.id;
  final result = await Isolate.run(() => parseM3u(_decode(bytes), id));
  if (result.values.every((c) => c.items.isEmpty)) {
    throw const AppException('Keine Einträge gefunden – ist das eine gültige M3U-Playlist?');
  }
  return result;
}

String _decode(List<int> bytes) {
  try {
    var s = utf8.decode(bytes);
    if (s.startsWith('﻿')) s = s.substring(1);
    return s;
  } catch (_) {
    return latin1.decode(bytes);
  }
}

final _attrRe = RegExp(r'([\w-]+)="([^"]*)"');

Map<Section, Catalog> parseM3u(String text, String sourceId) {
  final items = <Section, List<MediaItem>>{for (final s in Section.values) s: []};
  final cats = <Section, List<MediaCategory>>{for (final s in Section.values) s: []};
  final seen = <Section, Set<String>>{for (final s in Section.values) s: {}};

  Map<String, String>? attrs;
  String? name;
  String? group;
  final headers = <String, String>{};

  for (final raw in const LineSplitter().convert(text)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final upper = line.toUpperCase();
    if (upper.startsWith('#EXTINF')) {
      attrs = {for (final m in _attrRe.allMatches(line)) m.group(1)!: m.group(2)!};
      final rest = line.replaceAll(_attrRe, '');
      final comma = rest.indexOf(',');
      name = comma >= 0 ? rest.substring(comma + 1).trim() : '';
      group = attrs['group-title'];
    } else if (upper.startsWith('#EXTGRP:')) {
      group ??= line.substring(8).trim();
    } else if (upper.startsWith('#EXTVLCOPT:')) {
      final opt = line.substring(11).trim();
      final eq = opt.indexOf('=');
      if (eq > 0) {
        final k = opt.substring(0, eq).toLowerCase();
        final v = opt.substring(eq + 1);
        if (k == 'http-user-agent') headers['User-Agent'] = v;
        if (k == 'http-referrer' || k == 'http-referer') headers['Referer'] = v;
      }
    } else if (line.startsWith('#')) {
      continue;
    } else {
      final url = line;
      final lower = url.toLowerCase();
      final type = (attrs?['tvg-type'] ?? attrs?['type'] ?? '').toLowerCase();
      final section = (type == 'movie' || type == 'vod' || lower.contains('/movie/'))
          ? Section.movie
          : (type == 'series' || lower.contains('/series/'))
              ? Section.series
              : Section.live;
      final display = (name ?? '').isNotEmpty
          ? name!
          : (attrs?['tvg-name'] ?? url.split('/').last);
      final g = (group == null || group.trim().isEmpty) ? 'Ohne Gruppe' : group.trim();
      if (seen[section]!.add(g)) cats[section]!.add(MediaCategory(g, g));
      final logo = attrs?['tvg-logo'];
      items[section]!.add(MediaItem(
        sourceId: sourceId,
        section: section,
        name: display,
        categoryId: g,
        url: url,
        logo: (logo == null || logo.isEmpty) ? null : logo,
        headers: headers.isEmpty ? null : Map.of(headers),
      ));
      attrs = null;
      name = null;
      group = null;
      headers.clear();
    }
  }
  return {for (final s in Section.values) s: Catalog(cats[s]!, items[s]!)};
}
