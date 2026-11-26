import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'live_view.dart';
import 'player.dart';
import 'sidebar.dart';
import 'source_dialog.dart';
import 'vod_view.dart';
import 'widgets.dart';

/// Hauptlayout: Seitenleiste + Inhalt, darüber ggf. der Vollbild-Player.
class Shell extends StatelessWidget {
  const Shell({super.key});

  bool _typing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText || ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(BuildContext context, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final st = AppScope.read(context);
    final k = e.logicalKey;
    final hw = HardwareKeyboard.instance;
    final mod = hw.isControlPressed || hw.isMetaPressed;

    if (mod && k == LogicalKeyboardKey.keyB) {
      st.toggleSidebar();
      return KeyEventResult.handled;
    }
    if (mod && k == LogicalKeyboardKey.keyK) {
      if (st.fullscreen) exitFullscreen(st);
      searchFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      if (st.fullscreen) {
        exitFullscreen(st);
        return KeyEventResult.handled;
      }
      if (_typing()) {
        FocusManager.instance.primaryFocus?.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (_typing() || e is KeyRepeatEvent && k == LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.space) {
      st.togglePlay();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyF && !mod) {
      if (st.current == null) return KeyEventResult.ignored;
      st.fullscreen ? exitFullscreen(st) : enterFullscreen(st);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyM && !mod) {
      st.toggleMute();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyZ && st.fullscreen) {
      toggleZapPanel();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      if (st.current == null || st.zapList.length < 2) return KeyEventResult.ignored;
      st.zap(k == LogicalKeyboardKey.arrowUp ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (st.current != null && !st.current!.isLive &&
        (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight)) {
      final pos = st.player.state.position;
      st.player.seek(pos + Duration(seconds: k == LogicalKeyboardKey.arrowLeft ? -10 : 10));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    if (st.sources.isEmpty) return const Onboarding();

    final Widget content = switch (st.view) {
      AppView.live => const LiveView(),
      AppView.movie => const VodView(key: ValueKey('movie'), section: Section.movie),
      AppView.series => const VodView(key: ValueKey('series'), section: Section.series),
      AppView.resume => const ResumeView(),
      AppView.list => const UserListView(),
      AppView.search => const SearchView(),
    };

    return Focus(
      autofocus: true,
      onKeyEvent: (node, e) => _onKey(context, e),
      child: Stack(children: [
        Row(children: [
          const Sidebar(),
          Expanded(
            child: Column(children: [
              if (st.update != null) const _UpdateBanner(),
              Expanded(child: content),
              if (st.current != null && !st.viewHasPlayer && !st.fullscreen) const MiniPlayer(),
            ]),
          ),
        ]),
        if (st.fullscreen)
          Positioned.fill(child: FullscreenPlayer(key: fullscreenKey)),
      ]),
    );
  }
}

/// Erster Start: Begrüßung + Quelle hinzufügen.
class Onboarding extends StatelessWidget {
  const Onboarding({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Wrap(
          spacing: 96,
          runSpacing: 48,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            SizedBox(
              width: 440,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const AppLogo(size: 72),
                const SizedBox(height: 22),
                const Text('Willkommen bei noAd',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1)),
                const SizedBox(height: 22),
                const Text(
                  'Füge deine erste Quelle hinzu – danach sind Live-TV, Filme und Serien sofort da. '
                  'Du kannst später beliebig viele weitere Quellen ergänzen.',
                  style: TextStyle(fontSize: 16, height: 1.55, color: C.muted),
                ),
                const SizedBox(height: 30),
                for (final (i, t) in [
                  (1, 'Quelle hinzufügen'),
                  (2, 'Sender werden geladen'),
                  (3, 'Lieblingssender als Favoriten markieren'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 1 ? C.accent : null,
                          border: i == 1 ? null : Border.all(color: C.border2),
                          shape: BoxShape.circle,
                        ),
                        child: Text('$i',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: i == 1 ? C.onAccent : C.muted,
                            )),
                      ),
                      const SizedBox(width: 12),
                      Text(t, style: TextStyle(color: i == 1 ? C.text : C.muted)),
                    ]),
                  ),
              ]),
            ),
            Container(
              width: 520,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF14161B),
                border: Border.all(color: const Color(0xFF262A33)),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 64, offset: Offset(0, 24))],
              ),
              child: const SourceDialog(embedded: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hinweis auf eine neue Version.
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final u = st.update!;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF12231E),
        border: Border(bottom: BorderSide(color: Color(0xFF1F4A3C))),
      ),
      child: Row(children: [
        const Icon(Icons.system_update_alt_rounded, size: 18, color: C.accent),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Version ${u.version} ist verfügbar', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: '  ·  installiert: ${st.appVersion}', style: const TextStyle(color: C.muted)),
            ]),
            style: const TextStyle(fontSize: 13, color: Color(0xFFBFEFDF)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () => launchUrl(Uri.parse(u.pageUrl), mode: LaunchMode.externalApplication),
          child: const Text('Was ist neu?', style: TextStyle(color: C.text2)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 34,
          child: FilledButton.icon(
            onPressed: () => launchUrl(Uri.parse(u.downloadUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Herunterladen', style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: C.accent,
              foregroundColor: C.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Für diese Version ausblenden',
          onPressed: st.dismissUpdate,
          icon: const Icon(Icons.close_rounded, size: 18, color: C.muted),
        ),
      ]),
    );
  }
}

/// Schmale Player-Leiste unten, wenn die aktuelle Ansicht keinen Player hat
/// (z. B. Live-TV läuft weiter, während du durch Filme stöberst).
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cur = st.current!;
    final src = st.sourceById(cur.sourceId);
    final cat = cur.isLive ? st.categoryName(cur) : '';
    final sub = [src?.name ?? '', cat].where((e) => e.isNotEmpty).join(' · ');
    final backView = cur.isLive ? AppView.live : AppView.resume;
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: C.sidebar,
        border: Border(top: BorderSide(color: C.border)),
      ),
      child: Row(children: [
        // Kleines Live-Bild, Klick = Vollbild
        Tooltip(
          message: 'Vollbild (F)',
          child: GestureDetector(
            onTap: () => enterFullscreen(st),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 96,
                  height: 54,
                  child: Stack(fit: StackFit.expand, children: [
                    const ColoredBox(color: Colors.black),
                    Video(controller: st.video, controls: NoVideoControls, fill: Colors.black),
                    if (st.buffering)
                      const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: C.accent),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (cur.isLive) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: C.live, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(cur.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ]),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(sub,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: C.muted)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: st.player.state.playing ? 'Pause (Leertaste)' : 'Weiter (Leertaste)',
          onPressed: st.togglePlay,
          icon: Icon(st.player.state.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: C.text),
        ),
        const VolumeControl(),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Vollbild (F)',
          onPressed: () => enterFullscreen(st),
          icon: const Icon(Icons.fullscreen_rounded, color: C.text),
        ),
        const SizedBox(width: 4),
        SecondaryButton(
          label: cur.isLive ? 'Zu Live-TV' : 'Öffnen',
          icon: Icons.open_in_full_rounded,
          onPressed: () => st.showView(backView),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Wiedergabe beenden',
          onPressed: st.stop,
          icon: const Icon(Icons.close_rounded, color: C.muted),
        ),
      ]),
    );
  }
}
