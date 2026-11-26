import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'source_dialog.dart';
import 'widgets.dart';

const _wide = 232.0;
const _narrow = 72.0;

/// Seitenleiste; eingeklappt nur Icons (Strg/⌘ + B).
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: st.sidebarCollapsed ? _narrow : _wide,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: C.sidebar,
        border: Border(right: BorderSide(color: C.border)),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final c = box.maxWidth < 200;
        return Column(children: [
          Padding(
            padding: c ? const EdgeInsets.fromLTRB(0, 22, 0, 10) : const EdgeInsets.fromLTRB(22, 18, 10, 14),
            child: c
                ? Column(children: [
                    const AppLogo(size: 30),
                    const SizedBox(height: 10),
                    _SidebarToggle(collapsed: true, onTap: st.toggleSidebar),
                  ])
                : Row(children: [
                    const AppLogo(size: 30),
                    const SizedBox(width: 10),
                    const Text('noAd ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                    const Text('IPTV', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 17, color: C.muted)),
                    const Spacer(),
                    _SidebarToggle(collapsed: false, onTap: st.toggleSidebar),
                  ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _NavItem(c: c, icon: Icons.live_tv_rounded, label: 'Live-TV', view: AppView.live),
                _NavItem(c: c, icon: Icons.movie_outlined, label: 'Filme', view: AppView.movie),
                _NavItem(c: c, icon: Icons.video_library_outlined, label: 'Serien', view: AppView.series),
                _NavItem(
                  c: c,
                  icon: Icons.history_rounded,
                  label: 'Weiterschauen',
                  view: AppView.resume,
                  count: st.resumeList.length,
                ),
                _Group(c: c, label: 'Meine Listen'),
                for (final l in st.lists) _ListItem(c: c, list: l),
                _AddButton(c: c, label: 'Neue Liste', onTap: () => showListDialog(context)),
                _Group(c: c, label: 'Quellen'),
                for (final s in st.sources) _SourceItem(c: c, source: s),
                _AddButton(c: c, label: 'Quelle hinzufügen', onTap: () => showSourceDialog(context)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ]);
      }),
    );
  }
}

/// Klassisches „Seitenleiste“-Symbol zum Ein-/Ausklappen.
class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.collapsed, required this.onTap});
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: collapsed ? 'Seitenleiste einblenden (Strg/⌘ B)' : 'Seitenleiste ausblenden (Strg/⌘ B)',
        onPressed: onTap,
        hoverColor: const Color(0x14FFFFFF),
        icon: const CustomPaint(size: Size(20, 18), painter: _SidebarIconPainter()),
      );
}

class _SidebarIconPainter extends CustomPainter {
  const _SidebarIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = C.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6),
      const Radius.circular(4),
    );
    canvas.drawRRect(r, stroke);
    final x = size.width * 0.38;
    canvas.drawLine(Offset(x, 1), Offset(x, size.height - 1), stroke);
    final line = Paint()
      ..color = C.muted
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final y in [size.height * 0.32, size.height * 0.5]) {
      canvas.drawLine(Offset(3.6, y), Offset(x - 2.6, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Group extends StatelessWidget {
  const _Group({required this.c, required this.label});
  final bool c;
  final String label;

  @override
  Widget build(BuildContext context) => c
      ? const Padding(
          padding: EdgeInsets.fromLTRB(8, 16, 8, 12),
          child: Divider(height: 1, color: C.border),
        )
      : SectionLabel(label, padding: const EdgeInsets.fromLTRB(10, 22, 10, 8));
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.c, required this.icon, required this.label, required this.view, this.count});
  final bool c;
  final IconData icon;
  final String label;
  final AppView view;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final sel = st.view == view;
    final ic = Icon(icon, size: c ? 21 : 19, color: sel ? C.accent : C.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tile(
        height: c ? 44 : 40,
        selected: sel,
        accentBar: false,
        tooltip: c ? label : null,
        padding: c ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10),
        onTap: () => st.showView(view),
        child: c
            ? Center(child: ic)
            : Row(children: [
                ic,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                        color: sel ? C.text : C.text2,
                      )),
                ),
                if (count != null && count! > 0)
                  Text('$count', style: const TextStyle(fontSize: 12, color: C.faint)),
              ]),
      ),
    );
  }
}

/// Runder Buchstaben-Avatar für die eingeklappte Leiste.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.text, required this.color, this.fg = C.onAccent, this.size = 26});
  final String text;
  final Color color;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          text.isEmpty ? '?' : text.characters.first.toUpperCase(),
          style: TextStyle(fontSize: size * 0.46, fontWeight: FontWeight.w700, color: fg),
        ),
      );
}

class _ListItem extends StatelessWidget {
  const _ListItem({required this.c, required this.list});
  final bool c;
  final UserList list;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final sel = st.view == AppView.list && st.currentListId == list.id;
    final marker = list.isFavorites
        ? Icon(Icons.star_rounded, size: c ? 22 : 17, color: C.star)
        : c
            ? _Avatar(text: list.name, color: Color(list.color))
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: Color(list.color), shape: BoxShape.circle),
              );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tile(
        height: c ? 44 : 36,
        selected: sel,
        accentBar: false,
        tooltip: c ? '${list.name} (${list.items.length})' : null,
        padding: c ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10),
        onTap: () => st.showView(AppView.list, listId: list.id),
        onSecondaryTapDown: list.isFavorites ? null : (d) => _menu(context, d.globalPosition, st),
        child: c
            ? Center(child: marker)
            : Row(children: [
                SizedBox(width: 19, child: Center(child: marker)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(list.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sel ? C.text : C.text2, fontWeight: sel ? FontWeight.w600 : null)),
                ),
                Text('${list.items.length}', style: const TextStyle(fontSize: 12, color: C.faint)),
              ]),
      ),
    );
  }

  Future<void> _menu(BuildContext context, Offset pos, AppState st) async {
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: const [
        PopupMenuItem(value: 'edit', child: MenuRow(Icons.edit_outlined, 'Umbenennen…')),
        PopupMenuItem(value: 'del', child: MenuRow(Icons.delete_outline_rounded, 'Liste löschen')),
      ],
    );
    if (!context.mounted) return;
    if (v == 'edit') showListDialog(context, existing: list);
    if (v == 'del') {
      final undo = st.deleteList(list);
      showUndo(context, 'Liste „${list.name}“ gelöscht', undo);
    }
  }
}

class _SourceItem extends StatefulWidget {
  const _SourceItem({required this.c, required this.source});
  final bool c;
  final Source source;

  @override
  State<_SourceItem> createState() => _SourceItemState();
}

class _SourceItemState extends State<_SourceItem> {
  bool _hover = false;

  bool get c => widget.c;
  Source get source => widget.source;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.status[source.id];
    final sel = st.currentSourceId == source.id;
    final dot = switch (s?.state) {
      LoadState.loading => C.warn,
      LoadState.error => C.live,
      LoadState.ready => C.ok,
      _ => C.faint,
    };
    final status = s?.state == LoadState.loading
        ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: C.warn))
        : Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle));
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tile(
        height: c ? 44 : 36,
        selected: sel,
        accentBar: false,
        tooltip: c ? '${source.name}${s?.error != null ? ' – ${s!.error}' : ''}' : s?.error,
        padding: c ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10),
        onTap: () => st.selectSource(source.id),
        onSecondaryTapDown: (d) => _menu(context, d.globalPosition, st),
        child: c
            ? Center(
                child: Stack(clipBehavior: Clip.none, children: [
                  _Avatar(text: source.name, color: C.surfaceHi, fg: C.text),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: C.sidebar, shape: BoxShape.circle),
                      child: status,
                    ),
                  ),
                ]),
              )
            : Row(children: [
                SizedBox(width: 19, child: Center(child: status)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(source.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: sel ? C.text : C.text2, fontWeight: sel ? FontWeight.w600 : null)),
                ),
                if (_hover && s?.state != LoadState.loading)
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      tooltip: 'Playlist aktualisieren',
                      padding: EdgeInsets.zero,
                      iconSize: 17,
                      color: C.muted,
                      hoverColor: const Color(0x1A3EE0B0),
                      onPressed: () {
                        st.reloadSource(source);
                        showInfo(context, '„${source.name}“ wird aktualisiert…');
                      },
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  )
                else
                  TypeBadge(source.typeLabel),
              ]),
      ),
    ));
  }

  Future<void> _menu(BuildContext context, Offset pos, AppState st) async {
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: const [
        PopupMenuItem(value: 'reload', child: MenuRow(Icons.refresh_rounded, 'Neu laden')),
        PopupMenuItem(value: 'edit', child: MenuRow(Icons.edit_outlined, 'Bearbeiten…')),
        PopupMenuItem(value: 'del', child: MenuRow(Icons.delete_outline_rounded, 'Entfernen')),
      ],
    );
    if (!context.mounted) return;
    switch (v) {
      case 'reload':
        st.reloadSource(source);
      case 'edit':
        showSourceDialog(context, existing: source);
      case 'del':
        final undo = st.removeSource(source);
        showUndo(context, 'Quelle „${source.name}“ entfernt', undo);
    }
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.c, required this.label, required this.onTap});
  final bool c;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tile(
        height: c ? 44 : 36,
        tooltip: c ? label : null,
        padding: c ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 10),
        onTap: onTap,
        child: c
            ? const Center(child: Icon(Icons.add_rounded, size: 20, color: C.faint))
            : Row(children: [
                const SizedBox(width: 19, child: Icon(Icons.add, size: 17, color: C.faint)),
                const SizedBox(width: 12),
                Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.faint))),
              ]),
      );
}

/// Dialog: neue Liste anlegen oder umbenennen.
Future<UserList?> showListDialog(BuildContext context, {UserList? existing}) async {
  final st = AppScope.read(context);
  final ctrl = TextEditingController(text: existing?.name ?? '');
  var color = existing?.color ?? C.listColors[st.lists.length % C.listColors.length];
  return showDialog<UserList>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void save() {
          final name = ctrl.text.trim();
          if (name.isEmpty) return;
          if (existing != null) {
            st.renameList(existing, name, color);
            Navigator.pop(ctx, existing);
          } else {
            Navigator.pop(ctx, st.createList(name, color));
          }
        }

        return AlertDialog(
          title: Text(existing == null ? 'Neue Liste' : 'Liste bearbeiten',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'z. B. Sport, Kids, Nachrichten'),
                onSubmitted: (_) => save(),
              ),
              const SizedBox(height: 16),
              const Text('Farbe', style: TextStyle(fontSize: 13, color: C.text2)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, children: [
                for (final c in C.listColors)
                  Semantics(
                    button: true,
                    selected: c == color,
                    label: 'Farbe',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => color = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(color: c == color ? C.text : Colors.transparent, width: 2),
                        ),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            PrimaryButton(label: existing == null ? 'Anlegen' : 'Speichern', onPressed: save),
          ],
        );
      },
    ),
  );
}

/// Menü „Zu Liste…“ für einen Eintrag.
Future<void> showAddToListMenu(BuildContext context, MediaItem item, Offset pos) async {
  final st = AppScope.read(context);
  final v = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
    items: [
      for (final l in st.lists)
        CheckedPopupMenuItem(value: l.id, checked: l.contains(item), child: Text(l.name)),
      const PopupMenuDivider(),
      const PopupMenuItem(value: '__new', child: MenuRow(Icons.playlist_add_rounded, 'Neue Liste…')),
    ],
  );
  if (v == null || !context.mounted) return;
  if (v == '__new') {
    final l = await showListDialog(context);
    if (l != null) st.toggleInList(l, item);
    return;
  }
  final list = st.lists.firstWhere((l) => l.id == v);
  final added = st.toggleInList(list, item);
  if (context.mounted) {
    showInfo(context, added ? 'Zu „${list.name}“ hinzugefügt' : 'Aus „${list.name}“ entfernt');
  }
}
