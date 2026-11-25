// Datenmodelle für noAd IPTV Player.

enum SourceType { xtream, m3uUrl, m3uFile }

enum Section { live, movie, series }

extension SectionLabel on Section {
  String get label => switch (this) {
        Section.live => 'Live-TV',
        Section.movie => 'Filme',
        Section.series => 'Serien',
      };
}

class Source {
  Source({
    required this.id,
    required this.name,
    required this.type,
    this.server = '',
    this.user = '',
    this.pass = '',
    this.url = '',
    this.path = '',
  });

  final String id;
  String name;
  SourceType type;
  String server;
  String user;
  String pass;
  String url;
  String path;

  String get typeLabel => switch (type) {
        SourceType.xtream => 'Xtream',
        SourceType.m3uUrl => 'M3U',
        SourceType.m3uFile => 'M3U',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'server': server,
        'user': user,
        'pass': pass,
        'url': url,
        'path': path,
      };

  factory Source.fromJson(Map<String, dynamic> j) => Source(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Quelle',
        type: SourceType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => SourceType.m3uUrl,
        ),
        server: j['server'] as String? ?? '',
        user: j['user'] as String? ?? '',
        pass: j['pass'] as String? ?? '',
        url: j['url'] as String? ?? '',
        path: j['path'] as String? ?? '',
      );

  Source copy() => Source.fromJson(toJson());
}

class Category {
  const Category(this.id, this.name);
  final String id;
  final String name;
}

/// Ein Sender, Film, eine Serie oder eine Episode.
class MediaItem {
  const MediaItem({
    required this.sourceId,
    required this.section,
    required this.name,
    this.categoryId = '',
    this.url,
    this.logo,
    this.seriesId,
    this.meta,
    this.headers,
  });

  final String sourceId;
  final Section section;
  final String name;
  final String categoryId;

  /// Abspielbare URL. `null` bei einer Serie (erst Episoden laden).
  final String? url;
  final String? logo;
  final String? seriesId;

  /// Zusatzinfo, z. B. Jahr oder Staffel.
  final String? meta;

  /// HTTP-Header aus #EXTVLCOPT (z. B. User-Agent, Referrer).
  final Map<String, String>? headers;

  bool get isSeries => section == Section.series && url == null;
  bool get isLive => section == Section.live;

  /// Eindeutiger Schlüssel für Listen und Fortschritt.
  String get key => url ?? 'series:$sourceId:$seriesId';

  Map<String, dynamic> toJson() => {
        'sourceId': sourceId,
        'section': section.name,
        'name': name,
        'categoryId': categoryId,
        if (url != null) 'url': url,
        if (logo != null) 'logo': logo,
        if (seriesId != null) 'seriesId': seriesId,
        if (meta != null) 'meta': meta,
        if (headers != null) 'headers': headers,
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        sourceId: j['sourceId'] as String? ?? '',
        section: Section.values.firstWhere(
          (s) => s.name == j['section'],
          orElse: () => Section.live,
        ),
        name: j['name'] as String? ?? '',
        categoryId: j['categoryId'] as String? ?? '',
        url: j['url'] as String?,
        logo: j['logo'] as String?,
        seriesId: j['seriesId'] as String?,
        meta: j['meta'] as String?,
        headers: (j['headers'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      );
}

class Catalog {
  const Catalog(this.categories, this.items);
  final List<Category> categories;
  final List<MediaItem> items;

  static const empty = Catalog([], []);
}

class UserList {
  UserList({
    required this.id,
    required this.name,
    required this.color,
    List<MediaItem>? items,
  }) : items = items ?? [];

  final String id;
  String name;
  int color;
  final List<MediaItem> items;

  bool get isFavorites => id == favoritesId;
  static const favoritesId = 'fav';

  bool contains(MediaItem item) => items.any((i) => i.key == item.key);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory UserList.fromJson(Map<String, dynamic> j) => UserList(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Liste',
        color: j['color'] as int? ?? 0xFF7AA7FF,
        items: ((j['items'] as List?) ?? [])
            .map((e) => MediaItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Gespeicherter Wiedergabe-Fortschritt eines Films/einer Episode.
class Progress {
  const Progress({
    required this.item,
    required this.position,
    required this.duration,
    required this.updated,
    this.seriesName,
  });

  final MediaItem item;
  final Duration position;
  final Duration duration;
  final DateTime updated;
  final String? seriesName;

  double get fraction => duration.inMilliseconds <= 0
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  Duration get remaining => duration - position;

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'pos': position.inSeconds,
        'dur': duration.inSeconds,
        'upd': updated.millisecondsSinceEpoch,
        if (seriesName != null) 'series': seriesName,
      };

  factory Progress.fromJson(Map<String, dynamic> j) => Progress(
        item: MediaItem.fromJson(Map<String, dynamic>.from(j['item'] as Map)),
        position: Duration(seconds: j['pos'] as int? ?? 0),
        duration: Duration(seconds: j['dur'] as int? ?? 0),
        updated: DateTime.fromMillisecondsSinceEpoch(j['upd'] as int? ?? 0),
        seriesName: j['series'] as String?,
      );
}

/// Account-Infos eines Xtream-Zugangs.
class AccountInfo {
  const AccountInfo({this.expires, this.activeCons, this.maxCons});
  final DateTime? expires;
  final int? activeCons;
  final int? maxCons;
}
