import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models.dart';
import '../services/m3u.dart';
import '../services/net.dart';
import '../services/storage.dart';
import '../services/update.dart';
import '../services/xtream.dart';

/// Was in der Hauptfläche angezeigt wird.
enum AppView { live, movie, series, resume, list, search }

enum LoadState { idle, loading, ready, error }

class SourceStatus {
  LoadState state = LoadState.idle;
  String? error;
  AccountInfo? account;
}

class AppState extends ChangeNotifier {
  AppState(this._storage, {this.appVersion = ''}) {
    sources = _storage.loadSources();
    lists = _storage.loadLists();
    if (!lists.any((l) => l.isFavorites)) {
      lists.insert(0, UserList(id: UserList.favoritesId, name: 'Favoriten', color: 0xFFF5B942));
    }
    for (final p in _storage.loadProgress()) {
      progress[p.item.key] = p;
    }
    final last = _storage.lastSourceId;
    currentSourceId = sources.any((s) => s.id == last)
        ? last
        : (sources.isNotEmpty ? sources.first.id : null);

    player = Player(configuration: const PlayerConfiguration(title: 'noAd IPTV Player'));
    video = VideoController(player);
    volume = _storage.volume;
    sidebarCollapsed = _storage.sidebarCollapsed;
    player.setVolume(volume);
    _subs.addAll([
      player.stream.playing.listen((_) => notifyListeners()),
      player.stream.buffering.listen((b) {
        buffering = b;
        notifyListeners();
      }),
      player.stream.error.listen((e) {
        if (current != null) {
          playerError = 'Stream konnte nicht abgespielt werden – Sender offline oder gesperrt.';
          notifyListeners();
        }
      }),
      player.stream.position.listen(_onPosition),
      player.stream.duration.listen(_onDuration),
      player.stream.completed.listen((done) {
        if (done && current != null && !current!.isLive) {
          progress.remove(current!.key);
          _saveProgressSoon();
        }
      }),
    ]);

    for (final s in sources) {
      loadSection(s, Section.live);
    }
    Future.delayed(const Duration(seconds: 3), checkUpdate);
  }

  final String appVersion;

  // ------------------------------------------------------------- Oberfläche
  late bool sidebarCollapsed;

  final Map<String, double> _paneWidths = {};

  double paneWidth(String id, double fallback) =>
      _paneWidths[id] ??= _storage.paneWidth(id) ?? fallback;

  void setPaneWidth(String id, double w, {bool save = true}) {
    _paneWidths[id] = w;
    if (save) _storage.setPaneWidth(id, w);
    notifyListeners();
  }

  void toggleSidebar() {
    sidebarCollapsed = !sidebarCollapsed;
    _storage.sidebarCollapsed = sidebarCollapsed;
    notifyListeners();
  }

  // ---------------------------------------------------------------- Update
  UpdateInfo? update;

  Future<void> checkUpdate() async {
    if (appVersion.isEmpty) return;
    final u = await checkForUpdate(appVersion);
    if (u != null && u.version != _storage.dismissedUpdate) {
      update = u;
      notifyListeners();
    }
  }

  void dismissUpdate() {
    _storage.dismissedUpdate = update?.version;
    update = null;
    notifyListeners();
  }

  final Storage _storage;
  final _subs = <StreamSubscription>[];

  // ---------------------------------------------------------------- Daten
  late List<Source> sources;
  late List<UserList> lists;
  final Map<String, Progress> progress = {};

  final Map<String, SourceStatus> status = {};
  final Map<String, Map<Section, Catalog>> _catalogs = {};
  final Map<String, LoadState> _sectionState = {};
  final Map<String, String> _sectionError = {};
  final Map<String, XtreamClient> _clients = {};

  // ----------------------------------------------------------- Navigation
  AppView view = AppView.live;
  String? currentSourceId;
  String? currentListId;
  final Map<Section, String?> selectedCategory = {};
  String search = '';

  MediaItem? openSeries;
  Map<int, List<MediaItem>>? seriesEpisodes;
  int? seriesSeason;
  bool seriesLoading = false;
  String? seriesError;

  // --------------------------------------------------------------- Player
  late final Player player;
  late final VideoController video;
  MediaItem? current;
  String? currentSeriesName;
  bool buffering = false;
  String? playerError;
  bool fullscreen = false;
  Duration? _pendingSeek;
  DateTime _lastProgressSave = DateTime.fromMillisecondsSinceEpoch(0);

  Source? get currentSource {
    for (final s in sources) {
      if (s.id == currentSourceId) return s;
    }
    return null;
  }

  Source? sourceById(String id) {
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  UserList? get currentList {
    for (final l in lists) {
      if (l.id == currentListId) return l;
    }
    return null;
  }

  UserList get favorites => lists.firstWhere((l) => l.isFavorites);

  // ------------------------------------------------------------ Kataloge
  String _k(String sourceId, Section s) => '$sourceId/${s.name}';

  LoadState sectionState(String sourceId, Section s) =>
      _sectionState[_k(sourceId, s)] ?? LoadState.idle;

  String? sectionError(String sourceId, Section s) => _sectionError[_k(sourceId, s)];

  Catalog catalog(String sourceId, Section s) =>
      _catalogs[sourceId]?[s] ?? Catalog.empty;

  Future<void> loadSection(Source source, Section section, {bool force = false}) async {
    final key = _k(source.id, section);
    final st = _sectionState[key];
    if (!force && (st == LoadState.loading || st == LoadState.ready)) return;
    _sectionState[key] = LoadState.loading;
    final status = this.status.putIfAbsent(source.id, SourceStatus.new);
    if (section == Section.live) {
      status.state = LoadState.loading;
      status.error = null;
    }
    notifyListeners();
    try {
      if (source.type == SourceType.xtream) {
        var client = _clients[source.id];
        if (client == null || force) {
          client = XtreamClient(source);
          status.account = await client.login();
          _clients[source.id] = client;
        }
        final cat = await client.catalog(section);
        _catalogs.putIfAbsent(source.id, () => {})[section] = cat;
        _sectionState[key] = LoadState.ready;
      } else {
        // M3U: eine Datei enthält alle Bereiche.
        for (final s in Section.values) {
          _sectionState[_k(source.id, s)] = LoadState.loading;
        }
        final all = await loadM3u(source);
        _catalogs[source.id] = all;
        for (final s in Section.values) {
          _sectionState[_k(source.id, s)] = LoadState.ready;
        }
      }
      _sectionError.remove(key);
      if (status.state != LoadState.error) status.state = LoadState.ready;
    } catch (e) {
      final msg = friendlyError(e);
      if (source.type == SourceType.xtream) {
        _sectionState[key] = LoadState.error;
        _sectionError[key] = msg;
      } else {
        for (final s in Section.values) {
          _sectionState[_k(source.id, s)] = LoadState.error;
          _sectionError[_k(source.id, s)] = msg;
        }
      }
      if (section == Section.live || source.type != SourceType.xtream) {
        status.state = LoadState.error;
        status.error = msg;
      }
    }
    notifyListeners();
  }

  void reloadSource(Source source) {
    _clients.remove(source.id);
    _catalogs.remove(source.id);
    _sectionState.removeWhere((k, _) => k.startsWith('${source.id}/'));
    _sectionError.removeWhere((k, _) => k.startsWith('${source.id}/'));
    loadSection(source, Section.live, force: true);
    final sec = sectionForView;
    if (sec != null && sec != Section.live && source.type == SourceType.xtream) {
      loadSection(source, sec, force: true);
    }
  }

  Section? get sectionForView => switch (view) {
        AppView.live => Section.live,
        AppView.movie => Section.movie,
        AppView.series => Section.series,
        _ => null,
      };

  /// Gefilterte Einträge des aktuellen Bereichs (Quelle + Kategorie).
  List<MediaItem> visibleItems(Section section) {
    final src = currentSource;
    if (src == null) return const [];
    final all = catalog(src.id, section).items;
    final cat = selectedCategory[section];
    if (cat == null) return all;
    if (cat == '__fav__') {
      return favorites.items.where((i) => i.section == section && i.sourceId == src.id).toList();
    }
    return all.where((i) => i.categoryId == cat).toList();
  }

  /// Kategorien mit Anzahl, in Server-Reihenfolge.
  List<(MediaCategory, int)> categoriesWithCount(Section section) {
    final src = currentSource;
    if (src == null) return const [];
    final c = catalog(src.id, section);
    final counts = <String, int>{};
    for (final i in c.items) {
      counts[i.categoryId] = (counts[i.categoryId] ?? 0) + 1;
    }
    final out = <(MediaCategory, int)>[];
    final known = <String>{};
    for (final cat in c.categories) {
      known.add(cat.id);
      final n = counts[cat.id] ?? 0;
      if (n > 0) out.add((cat, n));
    }
    for (final e in counts.entries) {
      if (!known.contains(e.key)) {
        final label = (e.key.isEmpty || e.key == 'null') ? 'Ohne Kategorie' : e.key;
        out.add((MediaCategory(e.key, label), e.value));
      }
    }
    return out;
  }

  String categoryName(MediaItem item) {
    final c = _catalogs[item.sourceId]?[item.section]?.categories;
    if (c != null) {
      for (final cat in c) {
        if (cat.id == item.categoryId) return cat.name;
      }
    }
    return item.categoryId;
  }

  // ----------------------------------------------------------- Navigation
  void showView(AppView v, {String? listId}) {
    view = v;
    if (listId != null) currentListId = listId;
    if (v != AppView.search) search = '';
    if (v != AppView.series) closeSeries();
    final sec = sectionForView;
    final src = currentSource;
    if (sec != null && src != null) loadSection(src, sec);
    notifyListeners();
  }

  void selectSource(String id) {
    currentSourceId = id;
    _storage.lastSourceId = id;
    selectedCategory.clear();
    closeSeries();
    if (view != AppView.movie && view != AppView.series) view = AppView.live;
    final src = currentSource!;
    loadSection(src, sectionForView ?? Section.live);
    notifyListeners();
  }

  void selectCategory(Section s, String? id) {
    selectedCategory[s] = id;
    notifyListeners();
  }

  void setSearch(String q) {
    search = q;
    if (q.trim().isNotEmpty) {
      if (view != AppView.search) {
        view = AppView.search;
        _ensureAllLoaded();
      }
    } else if (view == AppView.search) {
      view = AppView.live;
    }
    notifyListeners();
  }

  void _ensureAllLoaded() {
    for (final s in sources) {
      for (final sec in Section.values) {
        loadSection(s, sec);
      }
    }
  }

  /// Ergebnisse der globalen Suche, gruppiert nach Bereich.
  Map<Section, List<MediaItem>> searchResults({int limit = 200}) {
    final q = search.trim().toLowerCase();
    final out = <Section, List<MediaItem>>{for (final s in Section.values) s: []};
    if (q.isEmpty) return out;
    for (final src in sources) {
      for (final sec in Section.values) {
        final list = out[sec]!;
        if (list.length >= limit) continue;
        for (final i in catalog(src.id, sec).items) {
          if (i.name.toLowerCase().contains(q)) {
            list.add(i);
            if (list.length >= limit) break;
          }
        }
      }
    }
    return out;
  }

  bool get anyLoading => _sectionState.values.any((s) => s == LoadState.loading);

  // -------------------------------------------------------------- Serien
  Future<void> openSeriesDetail(MediaItem series) async {
    openSeries = series;
    seriesEpisodes = null;
    seriesSeason = null;
    seriesError = null;
    seriesLoading = true;
    notifyListeners();
    try {
      final src = sourceById(series.sourceId);
      if (src == null) throw const AppException('Quelle nicht mehr vorhanden.');
      var client = _clients[src.id];
      if (client == null) {
        client = XtreamClient(src);
        await client.login();
        _clients[src.id] = client;
      }
      final eps = await client.episodes(series);
      if (openSeries?.key != series.key) return;
      seriesEpisodes = eps;
      final resume = resumeEpisode(series);
      seriesSeason = resume != null
          ? _seasonOf(resume.item)
          : (eps.keys.isNotEmpty ? eps.keys.first : null);
    } catch (e) {
      seriesError = friendlyError(e);
    }
    seriesLoading = false;
    notifyListeners();
  }

  int? _seasonOf(MediaItem ep) {
    final m = RegExp(r'^S(\d+)').firstMatch(ep.meta ?? '');
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  void selectSeason(int s) {
    seriesSeason = s;
    notifyListeners();
  }

  void closeSeries() {
    openSeries = null;
    seriesEpisodes = null;
    seriesSeason = null;
    seriesError = null;
    seriesLoading = false;
  }

  /// Zuletzt angefangene Episode einer Serie.
  Progress? resumeEpisode(MediaItem series) {
    Progress? best;
    for (final p in progress.values) {
      if (p.item.seriesId == series.seriesId && p.item.sourceId == series.sourceId) {
        if (best == null || p.updated.isAfter(best.updated)) best = p;
      }
    }
    return best;
  }

  List<Progress> get resumeList {
    final l = progress.values.where((p) => p.fraction < 0.95).toList()
      ..sort((a, b) => b.updated.compareTo(a.updated));
    return l;
  }

  void removeProgress(MediaItem item) {
    progress.remove(item.key);
    _saveProgressSoon(force: true);
    notifyListeners();
  }

  // -------------------------------------------------------------- Player
  Future<void> play(MediaItem item, {String? seriesName}) async {
    if (item.url == null) return;
    current = item;
    currentSeriesName = seriesName ?? (item.section == Section.series ? openSeries?.name : null);
    playerError = null;
    _pendingSeek = null;
    if (!item.isLive) {
      final p = progress[item.key];
      if (p != null && p.fraction < 0.95 && p.position.inSeconds > 10) {
        _pendingSeek = p.position;
      }
    }
    _storage.lastItem = item;
    notifyListeners();
    final headers = <String, String>{'User-Agent': userAgent, ...?item.headers};
    await player.open(Media(item.url!, httpHeaders: headers));
  }

  void togglePlay() {
    if (current == null) return;
    player.playOrPause();
  }

  Future<void> stop() async {
    await player.stop();
    current = null;
    playerError = null;
    notifyListeners();
  }

  late double volume;
  double _volumeBeforeMute = 80;

  void setVolume(double v) {
    volume = v.clamp(0, 100).toDouble();
    player.setVolume(volume);
    _storage.volume = volume;
    notifyListeners();
  }

  void toggleMute() {
    if (volume > 0) {
      _volumeBeforeMute = volume;
      setVolume(0);
    } else {
      setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 80);
    }
  }

  void setFullscreen(bool v) {
    fullscreen = v;
    notifyListeners();
  }

  /// Liste, in der mit ↑/↓ umgeschaltet wird.
  List<MediaItem> get zapList {
    final cur = current;
    if (cur == null) return const [];
    if (view == AppView.list) {
      return currentList?.items.where((i) => i.url != null).toList() ?? const [];
    }
    if (cur.isLive) {
      final visible = visibleItems(Section.live);
      if (visible.any((i) => i.key == cur.key)) return visible;
      return catalog(cur.sourceId, Section.live).items;
    }
    if (cur.section == Section.series && seriesEpisodes != null) {
      return seriesEpisodes!.values.expand((e) => e).toList();
    }
    return const [];
  }

  void zap(int delta) {
    final list = zapList;
    final cur = current;
    if (list.isEmpty || cur == null) return;
    var i = list.indexWhere((e) => e.key == cur.key);
    i = (i + delta) % list.length;
    if (i < 0) i += list.length;
    play(list[i]);
  }

  void _onDuration(Duration d) {
    final seek = _pendingSeek;
    if (seek != null && d > Duration.zero && seek < d) {
      _pendingSeek = null;
      player.seek(seek);
    }
  }

  void _onPosition(Duration pos) {
    final cur = current;
    if (cur == null || cur.isLive) return;
    final dur = player.state.duration;
    if (dur <= Duration.zero || pos.inSeconds < 10) return;
    progress[cur.key] = Progress(
      item: cur,
      position: pos,
      duration: dur,
      updated: DateTime.now(),
      seriesName: currentSeriesName,
    );
    _saveProgressSoon();
  }

  void _saveProgressSoon({bool force = false}) {
    final now = DateTime.now();
    if (!force && now.difference(_lastProgressSave).inSeconds < 10) return;
    _lastProgressSave = now;
    _storage.saveProgress(progress.values);
  }

  // -------------------------------------------------------------- Quellen
  String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  Source newSource() => Source(id: _newId(), name: '', type: SourceType.xtream);

  void addSource(Source s) {
    sources.add(s);
    _storage.saveSources(sources);
    selectSource(s.id);
  }

  void updateSource(Source s) {
    final i = sources.indexWhere((e) => e.id == s.id);
    if (i < 0) return;
    sources[i] = s;
    _storage.saveSources(sources);
    reloadSource(s);
    notifyListeners();
  }

  /// Entfernt eine Quelle; gibt eine Funktion zum Rückgängigmachen zurück.
  VoidCallback removeSource(Source s) {
    final index = sources.indexWhere((e) => e.id == s.id);
    sources.removeAt(index);
    _catalogs.remove(s.id);
    _clients.remove(s.id);
    status.remove(s.id);
    if (currentSourceId == s.id) {
      currentSourceId = sources.isNotEmpty ? sources.first.id : null;
      selectedCategory.clear();
    }
    _storage.saveSources(sources);
    notifyListeners();
    return () {
      sources.insert(index.clamp(0, sources.length), s);
      _storage.saveSources(sources);
      currentSourceId ??= s.id;
      loadSection(s, Section.live, force: true);
      notifyListeners();
    };
  }

  /// Prüft eine Quelle, ohne sie zu speichern. Gibt eine Zusammenfassung zurück.
  Future<String> testSource(Source s) async {
    if (s.type == SourceType.xtream) {
      final c = XtreamClient(s);
      final acc = await c.login();
      final live = await c.catalog(Section.live);
      final exp = acc.expires;
      return 'Verbunden · ${_fmtNum(live.items.length)} Sender'
          '${exp != null ? ' · gültig bis ${exp.day}.${exp.month}.${exp.year}' : ''}';
    }
    final all = await loadM3u(s);
    final n = all.values.fold<int>(0, (a, c) => a + c.items.length);
    return 'Playlist gelesen · ${_fmtNum(n)} Einträge';
  }

  // -------------------------------------------------------------- Listen
  bool isFavorite(MediaItem item) => favorites.contains(item);

  /// Schaltet Favorit um; gibt true zurück, wenn jetzt Favorit.
  bool toggleFavorite(MediaItem item) => toggleInList(favorites, item);

  bool toggleInList(UserList list, MediaItem item) {
    final i = list.items.indexWhere((e) => e.key == item.key);
    final added = i < 0;
    if (added) {
      list.items.add(item);
    } else {
      list.items.removeAt(i);
    }
    _storage.saveLists(lists);
    notifyListeners();
    return added;
  }

  UserList createList(String name, int color) {
    final l = UserList(id: _newId(), name: name, color: color);
    lists.add(l);
    _storage.saveLists(lists);
    notifyListeners();
    return l;
  }

  void renameList(UserList l, String name, int color) {
    l.name = name;
    l.color = color;
    _storage.saveLists(lists);
    notifyListeners();
  }

  VoidCallback deleteList(UserList l) {
    final index = lists.indexOf(l);
    lists.remove(l);
    if (currentListId == l.id && view == AppView.list) view = AppView.live;
    _storage.saveLists(lists);
    notifyListeners();
    return () {
      lists.insert(index.clamp(0, lists.length), l);
      _storage.saveLists(lists);
      notifyListeners();
    };
  }

  void moveInList(UserList l, int from, int to) {
    if (to > from) to -= 1;
    final item = l.items.removeAt(from);
    l.items.insert(to, item);
    _storage.saveLists(lists);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    player.dispose();
    super.dispose();
  }
}

String _fmtNum(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String fmtNum(int n) => _fmtNum(n);
