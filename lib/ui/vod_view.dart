import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'live_view.dart';
import 'player.dart';
import 'source_dialog.dart';
import 'widgets.dart';

/// Filme oder Serien der aktuellen Quelle.
class VodView extends StatelessWidget {
  const VodView({super.key, required this.section});
  final Section section;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final src = st.currentSource;
    return Column(children: [
      Header(title: section.label, subtitle: src?.name),
      Expanded(
        child: src == null
            ? EmptyState(
                icon: Icons.movie_outlined,
                title: 'Keine Quelle ausgewählt',
                action: PrimaryButton(label: 'Quelle hinzufügen', onPressed: () => showSourceDialog(context)),
              )
            : Row(children: [
                CategoryColumn(section: section),
                Expanded(
                  child: SectionBody(
                    section: section,
                    builder: (items) => _Grid(section: section, items: items),
                  ),
                ),
                if (section == Section.series && st.openSeries != null) const SeriesDetail(),
              ]),
      ),
    ]);
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.section, required this.items});
  final Section section;
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final srcId = st.currentSourceId;
    final resume = st.resumeList
        .where((p) => p.item.sourceId == srcId && p.item.section == section)
        .take(8)
        .toList();
    final noCategory = st.selectedCategory[section] == null;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: st.selectedCategory[section] == '__fav__' ? 'Noch keine Favoriten' : 'Keine Einträge',
        text: st.selectedCategory[section] == '__fav__' ? 'Rechtsklick auf ein Poster → „Zu Favoriten“.' : null,
      );
    }
    return Scrollbar(
      child: CustomScrollView(slivers: [
        if (resume.isNotEmpty && noCategory) ...[
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
            sliver: SliverToBoxAdapter(
              child: Text('Weiterschauen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 190,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: resume.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) => ResumeCard(progress: resume[i]),
              ),
            ),
          ),
        ],
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          sliver: SliverToBoxAdapter(
            child: Text('${fmtNum(items.length)} ${section == Section.movie ? 'Filme' : 'Serien'}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 170,
              mainAxisSpacing: 18,
              crossAxisSpacing: 16,
              childAspectRatio: 0.56,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => PosterCard(item: items[i]),
          ),
        ),
      ]),
    );
  }
}

class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final selected = st.openSeries?.key == item.key;
    final fav = st.isFavorite(item);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (item.isSeries) {
          st.openSeriesDetail(item);
        } else {
          st.play(item);
          enterFullscreen(st);
        }
      },
      onSecondaryTapDown: (d) => showItemMenu(context, item, d.globalPosition),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? C.accent : Colors.transparent, width: 2),
          ),
          padding: const EdgeInsets.all(2),
          child: Stack(children: [
            Poster(name: item.name, url: item.logo),
            if (fav)
              const Positioned(
                top: 6,
                right: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: C.overlay, shape: BoxShape.circle),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.star_rounded, size: 14, color: C.star),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25)),
        if (item.meta != null)
          Text(item.meta!, style: const TextStyle(fontSize: 12, color: C.muted)),
      ]),
    );
  }
}

class ResumeCard extends StatelessWidget {
  const ResumeCard({super.key, required this.progress});
  final Progress progress;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.read(context);
    final item = progress.item;
    final title = progress.seriesName ?? item.name;
    final sub = [
      if (progress.seriesName != null && item.meta != null) item.meta!,
      'noch ${progress.remaining.inMinutes} Min.',
    ].join(' · ');
    return SizedBox(
      width: 236,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          st.play(item, seriesName: progress.seriesName);
          enterFullscreen(st);
        },
        onSecondaryTapDown: (d) async {
          final v = await showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(d.globalPosition.dx, d.globalPosition.dy, d.globalPosition.dx, d.globalPosition.dy),
            items: const [PopupMenuItem(value: 'rm', child: Text('Aus „Weiterschauen“ entfernen'))],
          );
          if (v == 'rm') st.removeProgress(item);
        },
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 236,
              height: 133,
              child: Stack(fit: StackFit.expand, children: [
                if (item.logo != null && item.logo!.startsWith('http'))
                  Image.network(item.logo!, fit: BoxFit.cover, cacheWidth: 480,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2B3A55)))
                else
                  const ColoredBox(color: Color(0xFF2B3A55)),
                Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: C.overlay, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: C.text),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 4,
                    backgroundColor: C.overlay,
                    color: C.accent,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: C.muted)),
        ]),
      ),
    );
  }
}

/// Seitenpanel mit Staffeln und Episoden.
class SeriesDetail extends StatelessWidget {
  const SeriesDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.openSeries!;
    final eps = st.seriesEpisodes;
    final resume = st.resumeEpisode(s);
    final season = st.seriesSeason;
    final list = (eps != null && season != null) ? eps[season] ?? const <MediaItem>[] : const <MediaItem>[];
    final src = st.sourceById(s.sourceId);

    void playEp(MediaItem ep) {
      st.play(ep, seriesName: s.name);
      enterFullscreen(st);
    }

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: C.sidebar,
        border: Border(left: BorderSide(color: C.border)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Poster(name: s.name, url: s.logo)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(s.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.2)),
                ),
                IconButton(
                  tooltip: 'Schließen',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18, color: C.muted),
                  onPressed: () {
                    st.closeSeries();
                    st.showView(AppView.series);
                  },
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                [if (s.meta != null) s.meta!, if (eps != null) '${eps.length} Staffeln'].join(' · '),
                style: const TextStyle(fontSize: 12, color: C.muted),
              ),
              if (src != null)
                Text('Quelle: ${src.name}', style: const TextStyle(fontSize: 12, color: C.muted)),
              const SizedBox(height: 12),
              if (eps != null && eps.isNotEmpty)
                PrimaryButton(
                  icon: Icons.play_arrow_rounded,
                  label: resume != null ? '${resume.item.meta ?? ''} fortsetzen' : 'Abspielen',
                  onPressed: () => playEp(resume?.item ?? eps.values.first.first),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        if (st.seriesLoading) const Expanded(child: SkeletonList(rows: 6, rowHeight: 48)),
        if (st.seriesError != null)
          Expanded(
            child: ErrorPanel(message: st.seriesError!, onRetry: () => st.openSeriesDetail(s)),
          ),
        if (eps != null && eps.isEmpty)
          const Expanded(child: EmptyState(icon: Icons.inbox_outlined, title: 'Keine Episoden gefunden')),
        if (eps != null && eps.isNotEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final n in eps.keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Tile(
                      height: 36,
                      radius: 8,
                      accentBar: false,
                      selected: n == season,
                      selectedColor: const Color(0xFF232833),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      onTap: () => st.selectSeason(n),
                      child: Center(
                        child: Text('Staffel $n',
                            style: TextStyle(
                              fontSize: 13,
                              color: n == season ? C.text : C.muted,
                              fontWeight: n == season ? FontWeight.w600 : FontWeight.w400,
                            )),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) {
                final ep = list[i];
                final p = st.progress[ep.key];
                final watched = p != null && p.fraction >= 0.95;
                final stateText = p == null
                    ? ''
                    : watched
                        ? 'gesehen'
                        : '${p.remaining.inMinutes} Min. übrig';
                final num = RegExp(r'E(\d+)').firstMatch(ep.meta ?? '')?.group(1);
                return Opacity(
                  opacity: watched ? 0.6 : 1,
                  child: Tile(
                    height: 44,
                    selected: st.current?.key == ep.key || resume?.item.key == ep.key,
                    onTap: () => playEp(ep),
                    onSecondaryTapDown: (d) => showItemMenu(context, ep, d.globalPosition),
                    child: Row(children: [
                      SizedBox(
                        width: 30,
                        child: Text(num != null ? '${int.tryParse(num) ?? num}' : '${i + 1}',
                            style: const TextStyle(fontSize: 13, color: C.faint)),
                      ),
                      Expanded(
                        child: Text(ep.name,
                            overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      ),
                      Text(stateText, style: const TextStyle(fontSize: 12, color: C.faint)),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ]),
    );
  }
}

/// „Weiterschauen“ über alle Quellen.
class ResumeView extends StatelessWidget {
  const ResumeView({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final list = st.resumeList;
    return Column(children: [
      const Header(title: 'Weiterschauen'),
      Expanded(
        child: list.isEmpty
            ? const EmptyState(
                icon: Icons.history_rounded,
                title: 'Noch nichts angefangen',
                text: 'Filme und Episoden, die du nicht zu Ende schaust, erscheinen hier – mit der Stelle, an der du aufgehört hast.',
              )
            : GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 252,
                  mainAxisExtent: 190,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => ResumeCard(progress: list[i]),
              ),
      ),
    ]);
  }
}

/// Eigene Liste (inkl. Favoriten) mit Player daneben.
class UserListView extends StatelessWidget {
  const UserListView({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final l = st.currentList;
    if (l == null) return const SizedBox();
    return Column(children: [
      Header(title: l.name, subtitle: '${l.items.length} Einträge'),
      Expanded(
        child: Row(children: [
          Container(
            width: 420,
            decoration: const BoxDecoration(border: Border(right: BorderSide(color: C.border))),
            child: ItemList(
              items: l.items,
              showSource: true,
              reorderList: l,
              emptyText: l.isFavorites
                  ? 'Noch keine Favoriten – Rechtsklick auf einen Sender, Film oder eine Serie.'
                  : 'Liste ist leer – Rechtsklick auf einen Eintrag → „Zu Liste…“.',
              header: const Padding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text('Ziehen zum Sortieren · Rechtsklick für Optionen',
                    style: TextStyle(fontSize: 12, color: C.faint)),
              ),
            ),
          ),
          const Expanded(child: PlayerPanel()),
        ]),
      ),
    ]);
  }
}

/// Ergebnisse der globalen Suche.
class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final res = st.searchResults();
    final rows = <Object>[];
    for (final s in Section.values) {
      final l = res[s]!;
      if (l.isEmpty) continue;
      rows.add('${s.label} · ${l.length >= 200 ? '200+' : l.length}');
      rows.addAll(l);
    }
    return Column(children: [
      Header(title: 'Suche', subtitle: '„${st.search.trim()}“ in allen Quellen'),
      Expanded(
        child: Row(children: [
          Container(
            width: 460,
            decoration: const BoxDecoration(border: Border(right: BorderSide(color: C.border))),
            child: rows.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: st.anyLoading ? 'Quellen werden noch geladen…' : 'Nichts gefunden',
                    text: st.anyLoading ? null : 'Anderen Begriff versuchen oder Schreibweise prüfen.',
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      if (r is String) {
                        return SectionLabel(r, padding: const EdgeInsets.fromLTRB(16, 18, 16, 8));
                      }
                      final item = r as MediaItem;
                      return ItemRow(
                        item: item,
                        selected: st.current?.key == item.key,
                        showSource: true,
                        onOpenSeries: (s) {
                          st.setSearch('');
                          st.showView(AppView.series);
                          st.openSeriesDetail(s);
                        },
                      );
                    },
                  ),
          ),
          const Expanded(child: PlayerPanel()),
        ]),
      ),
    ]);
  }
}
