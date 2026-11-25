import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      View.live => const LiveView(),
      View.movie => const VodView(key: ValueKey('movie'), section: Section.movie),
      View.series => const VodView(key: ValueKey('series'), section: Section.series),
      View.resume => const ResumeView(),
      View.list => const UserListView(),
      View.search => const SearchView(),
    };

    return Focus(
      autofocus: true,
      onKeyEvent: (node, e) => _onKey(context, e),
      child: Stack(children: [
        Row(children: [
          const Sidebar(),
          Expanded(child: content),
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
