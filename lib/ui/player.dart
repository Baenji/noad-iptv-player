import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'sidebar.dart';
import 'widgets.dart';

Future<void> enterFullscreen(AppState st) async {
  st.setFullscreen(true);
  try {
    await windowManager.setFullScreen(true);
  } catch (_) {}
}

Future<void> exitFullscreen(AppState st) async {
  st.setFullscreen(false);
  try {
    await windowManager.setFullScreen(false);
  } catch (_) {}
}

/// Das Videobild (oder ein Platzhalter, solange nichts läuft).
class VideoSurface extends StatelessWidget {
  const VideoSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black),
      if (st.current != null)
        Video(controller: st.video, controls: NoVideoControls, fill: Colors.black),
      if (st.current != null && st.buffering && st.playerError == null)
        const Center(
          child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: C.accent)),
        ),
      if (st.playerError != null)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.portable_wifi_off_rounded, color: C.muted, size: 32),
              const SizedBox(height: 10),
              Text(st.playerError!, textAlign: TextAlign.center, style: const TextStyle(color: C.text2)),
              const SizedBox(height: 14),
              SecondaryButton(
                label: 'Erneut versuchen',
                icon: Icons.refresh,
                onPressed: () => st.play(st.current!),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Player rechts in der Live-/Listen-Ansicht.
class PlayerPanel extends StatelessWidget {
  const PlayerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cur = st.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(fit: StackFit.expand, children: [
              if (!st.fullscreen) const VideoSurface() else const ColoredBox(color: Colors.black),
              if (cur == null)
                const EmptyState(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Nichts ausgewählt',
                  text: 'Doppelklick auf einen Sender startet die Wiedergabe.',
                ),
              if (cur != null) ...[
                if (cur.isLive) const Positioned(top: 12, left: 12, child: LiveBadge()),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Row(children: [
                    _OverlayButton(
                      icon: st.player.state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      tooltip: 'Pause / Weiter (Leertaste)',
                      onTap: st.togglePlay,
                    ),
                    const SizedBox(width: 8),
                    _OverlayButton(
                      icon: Icons.fullscreen_rounded,
                      tooltip: 'Vollbild (F)',
                      onTap: () => enterFullscreen(st),
                    ),
                  ]),
                ),
              ],
              if (cur != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTap: () => enterFullscreen(st),
                    child: const SizedBox.expand(),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        if (cur != null) _NowInfo(item: cur),
        if (cur != null && !cur.isLive) ...[const SizedBox(height: 14), const _SeekBar()],
        const Spacer(),
        const Wrap(spacing: 18, runSpacing: 6, children: [
          _Key('Leertaste', 'Pause'),
          _Key('F', 'Vollbild'),
          _Key('↑ ↓', 'Sender'),
          _Key('Strg/⌘ K', 'Suche'),
        ]),
      ]),
    );
  }
}

class _NowInfo extends StatelessWidget {
  const _NowInfo({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final src = st.sourceById(item.sourceId);
    final cat = st.categoryName(item);
    final fav = st.isFavorite(item);
    final title = item.section == Section.series && st.currentSeriesName != null
        ? '${st.currentSeriesName} · ${item.meta ?? ''}'
        : (src?.name ?? '');
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            [title, if (cat.isNotEmpty && item.section != Section.series) cat].where((e) => e.isNotEmpty).join(' · '),
            style: const TextStyle(fontSize: 12, color: C.faint),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        ]),
      ),
      const SizedBox(width: 12),
      SecondaryButton(
        label: 'Favorit',
        icon: fav ? Icons.star_rounded : Icons.star_outline_rounded,
        iconColor: C.star,
        onPressed: () => st.toggleFavorite(item),
      ),
      const SizedBox(width: 8),
      Builder(
        builder: (ctx) => SecondaryButton(
          label: 'Zu Liste…',
          onPressed: () {
            final box = ctx.findRenderObject() as RenderBox;
            showAddToListMenu(ctx, item, box.localToGlobal(Offset(0, box.size.height + 4)));
          },
        ),
      ),
    ]);
  }
}

/// Spulbalken für Filme/Episoden.
class _SeekBar extends StatefulWidget {
  const _SeekBar({this.light = false});
  final bool light;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return StreamBuilder<Duration>(
      stream: st.player.stream.position,
      builder: (context, snap) {
        final pos = snap.data ?? st.player.state.position;
        final dur = st.player.state.duration;
        final max = dur.inMilliseconds.toDouble();
        final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max <= 0 ? 1.0 : max).toDouble();
        final style = TextStyle(fontSize: 12, color: widget.light ? C.text2 : C.muted);
        return Row(children: [
          Text(fmtDuration(Duration(milliseconds: value.round())), style: style),
          Expanded(
            child: Slider(
              value: value,
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0 ? null : (v) => setState(() => _drag = v),
              onChangeEnd: (v) {
                st.player.seek(Duration(milliseconds: v.round()));
                setState(() => _drag = null);
              },
            ),
          ),
          Text(fmtDuration(dur), style: style),
        ]);
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.k, this.label);
  final String k;
  final String label;
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: k, style: const TextStyle(fontWeight: FontWeight.w700, color: C.text2)),
          TextSpan(text: ' $label'),
        ]),
        style: const TextStyle(fontSize: 12, color: C.faint),
      );
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.icon, required this.onTap, required this.tooltip, this.size = 36, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: C.overlay,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, size: size * 0.5, color: color ?? C.text),
            ),
          ),
        ),
      );
}

/// Vollbild-Player mit automatisch ausblendender Steuerung.
class FullscreenPlayer extends StatefulWidget {
  const FullscreenPlayer({super.key});

  @override
  State<FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  bool _visible = true;
  bool _zapOpen = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _poke();
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  void _poke() {
    _hide?.cancel();
    if (!_visible) setState(() => _visible = true);
    _hide = Timer(const Duration(seconds: 3), () {
      if (mounted && !_zapOpen) setState(() => _visible = false);
    });
  }

  void toggleZap() {
    setState(() => _zapOpen = !_zapOpen);
    _poke();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cur = st.current;
    return MouseRegion(
      cursor: _visible ? SystemMouseCursors.basic : SystemMouseCursors.none,
      onHover: (_) => _poke(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _poke,
        onDoubleTap: () => exitFullscreen(st),
        child: Stack(fit: StackFit.expand, children: [
          const VideoSurface(),
          AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_visible,
              child: Stack(children: [
                // Oben
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(36, 28, 36, 40),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _OverlayButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Zurück (Esc)',
                        size: 44,
                        onTap: () => exitFullscreen(st),
                      ),
                      const SizedBox(width: 16),
                      if (cur != null)
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              if (cur.isLive) ...[const LiveBadge(solid: true), const SizedBox(width: 10)],
                              Text(
                                cur.section == Section.series
                                    ? '${st.currentSeriesName ?? ''} · ${cur.meta ?? ''}'
                                    : (st.sourceById(cur.sourceId)?.name ?? ''),
                                style: const TextStyle(fontSize: 14, color: C.text2),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(cur.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                    ]),
                  ),
                ),
                // Unten
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(36, 60, 36, 28),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xE6000000)],
                      ),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (cur != null && !cur.isLive) const _SeekBar(light: true),
                      const SizedBox(height: 10),
                      Row(children: [
                        if (st.zapList.length > 1)
                          _OverlayButton(
                            icon: Icons.keyboard_arrow_up_rounded,
                            tooltip: 'Vorheriger (↑)',
                            size: 48,
                            onTap: () => st.zap(-1),
                          ),
                        const SizedBox(width: 12),
                        Material(
                          color: C.text,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: st.togglePlay,
                            child: SizedBox(
                              width: 60,
                              height: 60,
                              child: Icon(
                                st.player.state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: C.bg,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (st.zapList.length > 1)
                          _OverlayButton(
                            icon: Icons.keyboard_arrow_down_rounded,
                            tooltip: 'Nächster (↓)',
                            size: 48,
                            onTap: () => st.zap(1),
                          ),
                        const Spacer(),
                        const Icon(Icons.volume_up_rounded, color: C.text2, size: 20),
                        SizedBox(
                          width: 130,
                          child: Slider(
                            value: st.volume.clamp(0.0, 100.0).toDouble(),
                            max: 100,
                            onChanged: st.setVolume,
                          ),
                        ),
                        if (cur != null) ...[
                          const SizedBox(width: 8),
                          _OverlayButton(
                            icon: st.isFavorite(cur) ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: C.star,
                            tooltip: 'Favorit',
                            size: 44,
                            onTap: () => st.toggleFavorite(cur),
                          ),
                        ],
                        if (st.zapList.length > 1) ...[
                          const SizedBox(width: 8),
                          _OverlayButton(
                            icon: Icons.list_rounded,
                            tooltip: 'Liste (Z)',
                            size: 44,
                            onTap: toggleZap,
                          ),
                        ],
                        const SizedBox(width: 8),
                        _OverlayButton(
                          icon: Icons.fullscreen_exit_rounded,
                          tooltip: 'Vollbild beenden (Esc)',
                          size: 44,
                          onTap: () => exitFullscreen(st),
                        ),
                      ]),
                    ]),
                  ),
                ),
                if (_zapOpen) Positioned(right: 36, top: 120, bottom: 150, child: _ZapPanel(onPick: _poke)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ZapPanel extends StatelessWidget {
  const _ZapPanel({required this.onPick});
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final list = st.zapList;
    final cur = st.current;
    final index = list.indexWhere((e) => e.key == cur?.key);
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xEB111318),
        border: Border.all(color: const Color(0xFF2A2F38)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        controller: ScrollController(initialScrollOffset: (index - 2).clamp(0, list.length).toDouble() * 52.0),
        itemCount: list.length,
        itemExtent: 52,
        itemBuilder: (_, i) {
          final it = list[i];
          return Tile(
            selected: i == index,
            selectedColor: const Color(0xFF232833),
            radius: 10,
            onTap: () {
              st.play(it);
              onPick();
            },
            child: Row(children: [
              LogoTile(name: it.name, url: it.logo, size: 34, radius: 8),
              const SizedBox(width: 12),
              Expanded(
                child: Text(it.meta != null && it.section == Section.series ? '${it.meta} · ${it.name}' : it.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Globaler Zugriff auf den Vollbild-State (für die Z-Taste).
final fullscreenKey = GlobalKey<_FullscreenPlayerState>();

void toggleZapPanel() => fullscreenKey.currentState?.toggleZap();
