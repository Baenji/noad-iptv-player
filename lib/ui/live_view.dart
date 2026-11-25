import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'player.dart';
import 'sidebar.dart';
import 'source_dialog.dart';
import 'widgets.dart';

/// Fokus des Suchfelds (für Strg/⌘+K).
final searchFocus = FocusNode(debugLabel: 'search');

class Header extends StatefulWidget {
  const Header({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  State<Header> createState() => _HeaderState();
}

class _HeaderState extends State<Header> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: AppScope.read(context).search);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    if (st.search.isEmpty && _ctrl.text.isNotEmpty) _ctrl.clear();
    final acc = st.currentSourceId == null ? null : st.status[st.currentSourceId!]?.account;
    final accText = [
      if (acc?.expires != null)
        'Gültig bis ${acc!.expires!.day.toString().padLeft(2, '0')}.${acc.expires!.month.toString().padLeft(2, '0')}.${acc.expires!.year}',
      if (acc?.maxCons != null) '${acc!.activeCons ?? 0}/${acc.maxCons} Verbindungen',
    ].join(' · ');
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.border))),
      child: Row(children: [
        Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        if (widget.subtitle != null) ...[
          const SizedBox(width: 14),
          Flexible(
            child: Text(widget.subtitle!,
                overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.faint)),
          ),
        ],
        const SizedBox(width: 28),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, minWidth: 220),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _ctrl,
              focusNode: searchFocus,
              onChanged: st.setSearch,
              onTapOutside: (_) =>
                  searchFocus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Alle Quellen durchsuchen',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                fillColor: C.surface,
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: C.faint),
                prefixIconConstraints: const BoxConstraints(minWidth: 38),
                suffixIcon: st.search.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Center(widthFactor: 1, child: TypeBadge('Strg K')),
                      )
                    : IconButton(
                        tooltip: 'Suche leeren',
                        icon: const Icon(Icons.close_rounded, size: 16, color: C.muted),
                        onPressed: () {
                          _ctrl.clear();
                          st.setSearch('');
                        },
                      ),
              ),
            ),
          ),
        ),
        const Spacer(),
        if (accText.isNotEmpty) Text(accText, style: const TextStyle(fontSize: 12, color: C.faint)),
      ]),
    );
  }
}

class LiveView extends StatelessWidget {
  const LiveView({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final src = st.currentSource;
    return Column(children: [
      Header(title: 'Live-TV', subtitle: src?.name),
      Expanded(
        child: src == null
            ? EmptyState(
                icon: Icons.live_tv_rounded,
                title: 'Keine Quelle ausgewählt',
                text: 'Füge eine Quelle hinzu, um Sender zu sehen.',
                action: PrimaryButton(label: 'Quelle hinzufügen', onPressed: () => showSourceDialog(context)),
              )
            : Row(children: [
                const CategoryColumn(section: Section.live),
                Container(
                  width: 380,
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: C.border))),
                  child: SectionBody(
                    section: Section.live,
                    builder: (items) => ItemList(
                      items: items,
                      header: _listHeader(st, items.length),
                      emptyText: st.selectedCategory[Section.live] == '__fav__'
                          ? 'Noch keine Favoriten. Rechtsklick auf einen Sender → „Favorit“.'
                          : 'Diese Kategorie ist leer.',
                    ),
                  ),
                ),
                const Expanded(child: PlayerPanel()),
              ]),
      ),
    ]);
  }

  Widget _listHeader(AppState st, int n) {
    final sel = st.selectedCategory[Section.live];
    String name = 'Alle Sender';
    if (sel == '__fav__') {
      name = 'Favoriten';
    } else if (sel != null) {
      for (final (c, _) in st.categoriesWithCount(Section.live)) {
        if (c.id == sel) name = c.name;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(children: [
        Expanded(
          child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Text('${fmtNum(n)} Sender · ↑↓ umschalten', style: const TextStyle(fontSize: 12, color: C.faint)),
      ]),
    );
  }
}

/// Zeigt Laden/Fehler/Inhalt eines Bereichs der aktuellen Quelle.
class SectionBody extends StatelessWidget {
  const SectionBody({required this.section, required this.builder});
  final Section section;
  final Widget Function(List<MediaItem>) builder;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final src = st.currentSource!;
    final state = st.sectionState(src.id, section);
    if (state == LoadState.error) {
      return ErrorPanel(
        message: st.sectionError(src.id, section) ?? 'Unbekannter Fehler',
        onRetry: () => st.loadSection(src, section, force: true),
      );
    }
    if (state != LoadState.ready) return const SkeletonList();
    return builder(st.visibleItems(section));
  }
}

class CategoryColumn extends StatelessWidget {
  const CategoryColumn({super.key, required this.section});
  final Section section;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final src = st.currentSource!;
    final ready = st.sectionState(src.id, section) == LoadState.ready;
    final cats = ready ? st.categoriesWithCount(section) : const <(MediaCategory, int)>[];
    final total = ready ? st.catalog(src.id, section).items.length : 0;
    final favCount = st.favorites.items.where((i) => i.section == section && i.sourceId == src.id).length;
    final sel = st.selectedCategory[section];

    Widget row(String? id, String label, int n, {IconData? icon}) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Tile(
            height: 36,
            selected: sel == id,
            onTap: () => st.selectCategory(section, id),
            child: Row(children: [
              if (icon != null) ...[Icon(icon, size: 16, color: C.star), const SizedBox(width: 8)],
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sel == id ? C.text : C.text2,
                      fontWeight: sel == id ? FontWeight.w600 : FontWeight.w400,
                    )),
              ),
              Text(fmtNum(n), style: const TextStyle(fontSize: 12, color: C.faint)),
            ]),
          ),
        );

    return Container(
      width: 232,
      decoration: const BoxDecoration(border: Border(right: BorderSide(color: C.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionLabel('Kategorien', padding: EdgeInsets.fromLTRB(20, 18, 10, 10)),
        Expanded(
          child: !ready
              ? const SizedBox()
              : Scrollbar(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                    itemCount: cats.length + 2,
                    itemBuilder: (_, i) {
                      if (i == 0) return row('__fav__', 'Favoriten', favCount, icon: Icons.star_rounded);
                      if (i == 1) return row(null, 'Alle', total);
                      final (c, n) = cats[i - 2];
                      return row(c.id, c.name, n);
                    },
                  ),
                ),
        ),
      ]),
    );
  }
}

/// Liste von Sendern/Einträgen; Klick spielt ab, Rechtsklick öffnet das Menü.
class ItemList extends StatelessWidget {
  const ItemList({
    super.key,
    required this.items,
    this.header,
    this.emptyText = 'Keine Einträge.',
    this.showSource = false,
    this.onOpenSeries,
    this.reorderList,
  });

  final List<MediaItem> items;
  final Widget? header;
  final String emptyText;
  final bool showSource;
  final void Function(MediaItem)? onOpenSeries;

  /// Wenn gesetzt, lassen sich Einträge per Ziehen sortieren.
  final UserList? reorderList;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    if (items.isEmpty) {
      return Column(children: [
        if (header != null) header!,
        Expanded(child: EmptyState(icon: Icons.inbox_outlined, title: emptyText)),
      ]);
    }
    Widget tile(int i) => ItemRow(
          key: ValueKey(items[i].key),
          item: items[i],
          selected: st.current?.key == items[i].key,
          showSource: showSource,
          onOpenSeries: onOpenSeries,
        );
    final list = reorderList != null
        ? ReorderableListView.builder(
            buildDefaultDragHandles: true,
            itemCount: items.length,
            onReorder: (a, b) => st.moveInList(reorderList!, a, b),
            itemBuilder: (_, i) => tile(i),
          )
        : Scrollbar(
            child: ListView.builder(
              itemCount: items.length,
              itemExtent: 66,
              itemBuilder: (_, i) => tile(i),
            ),
          );
    return Column(children: [
      if (header != null) header!,
      Expanded(child: list),
    ]);
  }
}

class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    required this.selected,
    this.showSource = false,
    this.onOpenSeries,
  });

  final MediaItem item;
  final bool selected;
  final bool showSource;
  final void Function(MediaItem)? onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.read(context);
    final fav = AppScope.of(context).isFavorite(item);
    final sub = [
      if (showSource) st.sourceById(item.sourceId)?.name ?? '',
      if (item.section != Section.live) item.section.label,
      if (item.meta != null) item.meta!,
      if (!showSource && item.section == Section.live) st.categoryName(item),
    ].where((e) => e.isNotEmpty).join(' · ');
    return SizedBox(
      height: 66,
      child: Tile(
        radius: 0,
        selected: selected,
        selectedColor: C.surfaceSel,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onTap: () => _activate(context),
        onSecondaryTapDown: (d) => showItemMenu(context, item, d.globalPosition),
        child: Row(children: [
          LogoTile(name: item.name, url: item.logo, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(item.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (fav) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star_rounded, size: 14, color: C.star),
                  ],
                ]),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(sub,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: C.muted)),
                ],
              ],
            ),
          ),
          if (item.isSeries) const Icon(Icons.chevron_right_rounded, color: C.faint),
          if (selected && !item.isSeries) const Icon(Icons.graphic_eq_rounded, size: 18, color: C.accent),
        ]),
      ),
    );
  }

  void _activate(BuildContext context) {
    final st = AppScope.read(context);
    if (item.isSeries) {
      if (onOpenSeries != null) {
        onOpenSeries!(item);
      } else {
        st.showView(AppView.series);
        st.openSeriesDetail(item);
      }
      return;
    }
    st.play(item);
    if (!item.isLive) enterFullscreen(st);
  }
}

Future<void> showItemMenu(BuildContext context, MediaItem item, Offset pos) async {
  final st = AppScope.read(context);
  final fav = st.isFavorite(item);
  final v = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
    items: [
      if (!item.isSeries)
        const PopupMenuItem(value: 'play', child: MenuRow(Icons.play_arrow_rounded, 'Abspielen')),
      PopupMenuItem(
        value: 'fav',
        child: MenuRow(fav ? Icons.star_rounded : Icons.star_outline_rounded,
            fav ? 'Aus Favoriten entfernen' : 'Zu Favoriten',
            color: C.star),
      ),
      const PopupMenuItem(value: 'list', child: MenuRow(Icons.playlist_add_rounded, 'Zu Liste…')),
      if (item.url != null)
        const PopupMenuItem(value: 'copy', child: MenuRow(Icons.link_rounded, 'Stream-URL kopieren')),
    ],
  );
  if (!context.mounted) return;
  switch (v) {
    case 'play':
      st.play(item);
    case 'fav':
      final added = st.toggleFavorite(item);
      showInfo(context, added ? 'Zu Favoriten hinzugefügt' : 'Aus Favoriten entfernt');
    case 'list':
      await showAddToListMenu(context, item, pos);
    case 'copy':
      await Clipboard.setData(ClipboardData(text: item.url!));
      if (context.mounted) showInfo(context, 'Stream-URL kopiert');
  }
}
