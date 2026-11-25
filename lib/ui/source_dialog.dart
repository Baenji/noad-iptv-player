import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/net.dart';
import '../theme.dart';
import 'widgets.dart';

Future<void> showSourceDialog(BuildContext context, {Source? existing}) => showDialog(
      context: context,
      builder: (_) => SourceDialog(existing: existing),
    );

/// Quelle hinzufügen oder bearbeiten (Xtream, M3U-Link, M3U-Datei).
class SourceDialog extends StatefulWidget {
  const SourceDialog({super.key, this.existing, this.embedded = false});
  final Source? existing;

  /// true: im Onboarding ohne Dialog-Rahmen anzeigen.
  final bool embedded;

  @override
  State<SourceDialog> createState() => _SourceDialogState();
}

class _SourceDialogState extends State<SourceDialog> {
  late Source s;
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _url = TextEditingController();
  bool _showPass = false;
  bool _testing = false;
  String? _testOk;
  String? _error;

  @override
  void initState() {
    super.initState();
    final st = AppScope.read(context);
    s = widget.existing?.copy() ?? st.newSource();
    _name.text = s.name;
    _server.text = s.server;
    _user.text = s.user;
    _pass.text = s.pass;
    _url.text = s.url;
  }

  @override
  void dispose() {
    for (final c in [_name, _server, _user, _pass, _url]) {
      c.dispose();
    }
    super.dispose();
  }

  void _collect() {
    s
      ..name = _name.text.trim()
      ..server = _server.text.trim()
      ..user = _user.text.trim()
      ..pass = _pass.text.trim()
      ..url = _url.text.trim();
    // get.php-Link mit Zugangsdaten automatisch als Xtream behandeln.
    if (s.type == SourceType.m3uUrl && s.url.contains('get.php')) {
      final uri = Uri.tryParse(s.url);
      final u = uri?.queryParameters['username'];
      final p = uri?.queryParameters['password'];
      if (uri != null && u != null && p != null) {
        s
          ..type = SourceType.xtream
          ..server = '${uri.scheme}://${uri.authority}'
          ..user = u
          ..pass = p;
      }
    }
    if (s.name.isEmpty) {
      s.name = switch (s.type) {
        SourceType.xtream => Uri.tryParse(s.server.startsWith('http') ? s.server : 'http://${s.server}')?.host ?? 'Xtream',
        SourceType.m3uUrl => Uri.tryParse(s.url)?.host ?? 'Playlist',
        SourceType.m3uFile => s.path.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'\.m3u8?$'), ''),
      };
    }
  }

  String? _validate() {
    switch (s.type) {
      case SourceType.xtream:
        if (s.server.isEmpty || s.user.isEmpty || s.pass.isEmpty) {
          return 'Bitte Server-URL, Benutzername und Passwort ausfüllen.';
        }
      case SourceType.m3uUrl:
        if (!s.url.startsWith('http')) return 'Bitte einen gültigen Link (http…) eingeben.';
      case SourceType.m3uFile:
        if (s.path.isEmpty) return 'Bitte eine Datei auswählen.';
    }
    final st = AppScope.read(context);
    if (st.sources.any((e) => e.id != s.id && e.name == s.name)) {
      return 'Eine Quelle mit diesem Namen gibt es schon.';
    }
    return null;
  }

  Future<void> _test() async {
    _collect();
    final err = _validate();
    setState(() {
      _error = err;
      _testOk = null;
    });
    if (err != null) return;
    setState(() => _testing = true);
    try {
      final msg = await AppScope.read(context).testSource(s);
      if (mounted) setState(() => _testOk = msg);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _save() {
    _collect();
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final st = AppScope.read(context);
    if (widget.existing != null) {
      st.updateSource(s);
    } else {
      st.addSource(s);
    }
    if (!widget.embedded) Navigator.of(context).pop();
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8'],
      dialogTitle: 'Playlist auswählen',
    );
    final path = r?.files.single.path;
    if (path != null) {
      setState(() {
        s.path = path;
        _error = null;
      });
    }
  }

  Widget _field(String label, TextEditingController c,
      {String? hint, String? help, bool obscure = false, Widget? suffix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: C.text2)),
      const SizedBox(height: 6),
      TextField(
        controller: c,
        obscureText: obscure,
        onSubmitted: (_) => _save(),
        onChanged: (_) {
          if (_error != null || _testOk != null) {
            setState(() {
              _error = null;
              _testOk = null;
            });
          }
        },
        decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
      ),
      if (help != null) ...[
        const SizedBox(height: 6),
        Text(help, style: const TextStyle(fontSize: 12, color: C.faint)),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final types = [
      (SourceType.xtream, 'Xtream Codes'),
      (SourceType.m3uUrl, 'M3U-Link'),
      (SourceType.m3uFile, 'M3U-Datei'),
    ];
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.existing == null ? 'Quelle hinzufügen' : 'Quelle bearbeiten',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            for (final (t, label) in types)
              Expanded(
                child: Tile(
                  height: 36,
                  radius: 7,
                  selected: s.type == t,
                  accentBar: false,
                  selectedColor: const Color(0xFF232833),
                  onTap: () => setState(() {
                    s.type = t;
                    _error = null;
                    _testOk = null;
                  }),
                  child: Center(
                    child: Text(label,
                        style: TextStyle(
                          fontSize: 13,
                          color: s.type == t ? C.text : C.muted,
                          fontWeight: s.type == t ? FontWeight.w600 : FontWeight.w400,
                        )),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        _field('Name', _name, hint: 'z. B. Anbieter A (optional)'),
        const SizedBox(height: 16),
        if (s.type == SourceType.xtream) ...[
          _field('Server-URL', _server, hint: 'http://anbieter.example:8080', help: 'Mit Port, ohne /player_api.php'),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _field('Benutzername', _user)),
            const SizedBox(width: 12),
            Expanded(
              child: _field('Passwort', _pass,
                  obscure: !_showPass,
                  suffix: IconButton(
                    tooltip: _showPass ? 'Passwort verbergen' : 'Passwort anzeigen',
                    icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18, color: C.muted),
                    onPressed: () => setState(() => _showPass = !_showPass),
                  )),
            ),
          ]),
        ],
        if (s.type == SourceType.m3uUrl)
          _field('Playlist-Link', _url,
              hint: 'https://…/playlist.m3u',
              help: 'Ein get.php-Link mit Benutzer und Passwort wird automatisch als Xtream erkannt.'),
        if (s.type == SourceType.m3uFile)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _pickFile,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                color: C.field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3A404B)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.upload_file_rounded, color: C.muted),
                const SizedBox(height: 8),
                Text(
                  s.path.isEmpty ? '.m3u-Datei auswählen' : s.path.split(RegExp(r'[\\/]')).last,
                  style: TextStyle(color: s.path.isEmpty ? C.muted : C.text),
                ),
              ]),
            ),
          ),
        if (_error != null || _testOk != null) ...[
          const SizedBox(height: 16),
          _Notice(ok: _error == null, text: _error ?? _testOk!),
        ],
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (!widget.embedded)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen', style: TextStyle(color: C.text2)),
            ),
          const Spacer(),
          SecondaryButton(
            label: _testing ? 'Teste…' : 'Verbindung testen',
            onPressed: _testing ? null : _test,
          ),
          const SizedBox(width: 10),
          PrimaryButton(
            label: widget.existing == null ? 'Hinzufügen' : 'Speichern',
            onPressed: _save,
          ),
        ]),
        const SizedBox(height: 14),
        const Text('Zugangsdaten werden nur lokal auf diesem Gerät gespeichert.',
            style: TextStyle(fontSize: 12, color: C.faint)),
      ],
    );

    if (widget.embedded) return content;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(padding: const EdgeInsets.all(28), child: SingleChildScrollView(child: content)),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.ok, required this.text});
  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ok ? const Color(0xFF12231E) : const Color(0xFF2A1416),
          border: Border.all(color: ok ? const Color(0xFF1F4A3C) : const Color(0xFF5A2A2E)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(ok ? Icons.check_rounded : Icons.error_outline_rounded,
              size: 18, color: ok ? C.ok : C.live),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: ok ? const Color(0xFFBFEFDF) : const Color(0xFFFFC9CB))),
          ),
        ]),
      );
}
