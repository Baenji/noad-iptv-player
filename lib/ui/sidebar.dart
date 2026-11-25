import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'source_dialog.dart';
import 'widgets.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Container(
      width: 232,
      decoration: const BoxDecoration(
        color: C.sidebar,
        border: Border(right: BorderSide(color: C.border)),
      ),
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 22, 12, 18),
          child: Row(children: [
            AppLogo(size: 30),
            SizedBox(width: 10),
            Text('noAd ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text('IPTV', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 17, color: C.muted)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _NavItem(icon: Icons.live_tv_rounded, label: 'Live-TV', view: View.live),
              _NavItem(icon: Icons.movie_outlined, label: 'Filme', view: View.movie),
              _NavItem(icon: Icons.video_library_outlined, label: 'Serien', view: View.series),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'Weiterschauen',
                view: View.resume,
                count: st.resumeList.length,
              ),
              const SectionLabel('Meine Listen', padding: EdgeInsets.fromLTRB(10, 22, 10, 8)),
              for (final l in st.lists) _ListItem(list: l),
              _AddButton(label: 'Neue Liste', onTap: () => showListDialog(context)),
              const SectionLabel('Quellen', padding: EdgeInsets.fromLTRB(10, 22, 10, 8)),
              for (final s in st.sources) _SourceItem(source: s),
              _AddButton(label: 'Quelle hinzufügen', onTap: () => showSourceDialog(context)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.view, this.count});
  final IconData icon;
  final String label;
  final View view;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final sel = st.view == view;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tile(
        height: 40,
        selected: sel,
        accentBar: false,
        onTap: () => st.showView(view),
        child: Row(children: [
          Icon(icon, size: 19, color: sel ? C.accent : C.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
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

class _ListItem extends StatelessWidget {
  const _ListItem({required this.list});
  final UserList list;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final sel = st.view == View.list && st.currentListId == list.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tile(
        height: 36,
        selected: sel,
        accentBar: false,
        onTap: () => st.showView(View.list, listId: list.id),
        onSecondaryTapDown: list.isFavorites
            ? null
            : (d) => _menu(context, d.globalPosition, st),
        child: Row(children: [
          SizedBox(
            width: 19,
            child: list.isFavorites
                ? const Icon(Icons.star_rounded, size: 17, color: C.star)
                : Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: Color(list.color), shape: BoxShape.circle),
                    ),
                  ),
          ),
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
        PopupMenuItem(value: 'edit', child: Text('Umbenennen…')),
        PopupMenuItem(value: 'del', child: Text('Liste löschen')),
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

class _SourceItem extends StatelessWidget {
  const _SourceItem({required this.source});
  final Source source;

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tile(
        height: 36,
        selected: sel,
        accentBar: false,
        tooltip: s?.error,
        onTap: () => st.selectSource(source.id),
        onSecondaryTapDown: (d) => _menu(context, d.globalPosition, st),
        child: Row(children: [
          SizedBox(
            width: 19,
            child: Center(
              child: s?.state == LoadState.loading
                  ? const SizedBox(
                      width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: C.warn))
                  : Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(source.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: sel ? C.text : C.text2, fontWeight: sel ? FontWeight.w600 : null)),
          ),
          TypeBadge(source.typeLabel),
        ]),
      ),
    );
  }

  Future<void> _menu(BuildContext context, Offset pos, AppState st) async {
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      items: const [
        PopupMenuItem(value: 'reload', child: Text('Neu laden')),
        PopupMenuItem(value: 'edit', child: Text('Bearbeiten…')),
        PopupMenuItem(value: 'del', child: Text('Entfernen')),
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
  const _AddButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tile(
        height: 36,
        onTap: onTap,
        child: Row(children: [
          const SizedBox(width: 19, child: Icon(Icons.add, size: 17, color: C.faint)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: C.faint)),
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
      const PopupMenuItem(value: '__new', child: Text('Neue Liste…')),
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
