import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Speichert Quellen, Listen, Fortschritt und Einstellungen lokal.
class Storage {
  Storage(this._prefs);
  final SharedPreferences _prefs;

  static Future<Storage> open() async => Storage(await SharedPreferences.getInstance());

  List<T> _readList<T>(String key, T Function(Map<String, dynamic>) f) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Source> loadSources() => _readList('sources', Source.fromJson);
  Future<void> saveSources(List<Source> s) =>
      _prefs.setString('sources', jsonEncode(s.map((e) => e.toJson()).toList()));

  List<UserList> loadLists() => _readList('lists', UserList.fromJson);
  Future<void> saveLists(List<UserList> l) =>
      _prefs.setString('lists', jsonEncode(l.map((e) => e.toJson()).toList()));

  List<Progress> loadProgress() => _readList('progress', Progress.fromJson);
  Future<void> saveProgress(Iterable<Progress> p) =>
      _prefs.setString('progress', jsonEncode(p.map((e) => e.toJson()).toList()));

  String? get lastSourceId => _prefs.getString('lastSource');
  set lastSourceId(String? v) =>
      v == null ? _prefs.remove('lastSource') : _prefs.setString('lastSource', v);

  MediaItem? get lastItem {
    final raw = _prefs.getString('lastItem');
    if (raw == null) return null;
    try {
      return MediaItem.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  set lastItem(MediaItem? v) => v == null
      ? _prefs.remove('lastItem')
      : _prefs.setString('lastItem', jsonEncode(v.toJson()));

  double get volume => _prefs.getDouble('volume') ?? 80;
  set volume(double v) => _prefs.setDouble('volume', v);

  double? paneWidth(String id) => _prefs.getDouble('pane_$id');
  void setPaneWidth(String id, double w) => _prefs.setDouble('pane_$id', w);

  bool get sidebarCollapsed => _prefs.getBool('sidebarCollapsed') ?? false;
  set sidebarCollapsed(bool v) => _prefs.setBool('sidebarCollapsed', v);

  String? get dismissedUpdate => _prefs.getString('dismissedUpdate');
  set dismissedUpdate(String? v) =>
      v == null ? _prefs.remove('dismissedUpdate') : _prefs.setString('dismissedUpdate', v);
}
