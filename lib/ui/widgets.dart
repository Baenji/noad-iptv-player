import 'package:flutter/material.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Macht den AppState im Widget-Baum verfügbar und baut bei Änderungen neu.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Zugriff ohne Neuaufbau (für Callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// App-Icon „Monogramm n“ (Richtung C).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    canvas.scale(s);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 64, 64), const Radius.circular(14)),
      Paint()..color = const Color(0xFF0F1E1A),
    );
    final path = Path()
      ..moveTo(20, 48)
      ..lineTo(20, 30)
      ..arcToPoint(const Offset(44, 30), radius: const Radius.circular(12))
      ..lineTo(44, 48);
    canvas.drawPath(
      path,
      Paint()
        ..color = C.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(48, 16), 5, Paint()..color = C.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(10, 20, 10, 8)});
  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: C.faint,
          ),
        ),
      );
}

/// Zeile mit Hover-, Auswahl- und Fokus-Zustand.
class Tile extends StatelessWidget {
  const Tile({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTapDown,
    this.selected = false,
    this.accentBar = true,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
    this.radius = 8,
    this.selectedColor = C.surfaceHi,
    this.tooltip,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final GestureTapDownCallback? onSecondaryTapDown;
  final bool selected;
  final bool accentBar;
  final double? height;
  final EdgeInsets padding;
  final double radius;
  final Color selectedColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    Widget w = Material(
      color: selected ? selectedColor : Colors.transparent,
      borderRadius: br,
      child: InkWell(
        borderRadius: br,
        hoverColor: const Color(0x0DFFFFFF),
        focusColor: const Color(0x1A3EE0B0),
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onSecondaryTapDown: onSecondaryTapDown,
        child: Stack(children: [
          Container(height: height, padding: padding, child: child),
          if (selected && accentBar)
            Positioned(
              left: 0,
              top: 6,
              bottom: 6,
              child: Container(
                width: 3,
                decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ]),
      ),
    );
    if (tooltip != null) w = Tooltip(message: tooltip!, child: w);
    return w;
  }
}

/// Senderlogo mit Fallback auf farbige Initialen.
class LogoTile extends StatelessWidget {
  const LogoTile({super.key, required this.name, this.url, this.size = 44, this.radius = 10});
  final String name;
  final String? url;
  final double size;
  final double radius;

  static const _tiles = [
    Color(0xFF2A3A5C), Color(0xFF3A2F4F), Color(0xFF1F4A43), Color(0xFF4F2F2F),
    Color(0xFF40432A), Color(0xFF2F3B4F), Color(0xFF23463A), Color(0xFF4A3A2A),
    Color(0xFF3D2A4A),
  ];

  String get _initials {
    final words = name
        .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length.clamp(1, 2)).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _tiles[name.hashCode.abs() % _tiles.length],
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        _initials,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * 0.3, color: C.text),
      ),
    );
    final u = url;
    if (u == null || !u.startsWith('http')) return fallback;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF1A1D23),
        padding: EdgeInsets.all(size * 0.1),
        child: Image.network(
          u,
          cacheWidth: (size * dpr).round(),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Transform.scale(scale: 1.25, child: fallback),
        ),
      ),
    );
  }
}

/// Poster (2:3) mit Fallback.
class Poster extends StatelessWidget {
  const Poster({super.key, required this.name, this.url, this.radius = 10});
  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(12),
      color: LogoTile._tiles[name.hashCode.abs() % LogoTile._tiles.length],
      child: Text(
        name,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
      ),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: (u == null || !u.startsWith('http'))
            ? fallback
            : Image.network(
                u,
                fit: BoxFit.cover,
                cacheWidth: 360,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: C.border2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11, color: C.faint)),
      );
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.solid = false});
  final bool solid;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: solid ? C.live : C.overlay,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!solid) ...[
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: C.live, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          const Text('LIVE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
      );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon, this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: FilledButton.icon(
          onPressed: busy ? null : onPressed,
          icon: busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: C.onAccent))
              : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: C.accent,
            foregroundColor: C.onAccent,
            disabledBackgroundColor: const Color(0xFF2A5E50),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon, this.iconColor});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon, size: 18, color: iconColor) : const SizedBox.shrink(),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: C.text,
            backgroundColor: C.surface,
            side: const BorderSide(color: C.border2),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}

/// Leerer Zustand mit Erklärung und optionaler Aktion.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 36, color: C.faint),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (text != null) ...[
              const SizedBox(height: 6),
              Text(text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ]),
        ),
      );
}

/// Fehler mit „Erneut versuchen“.
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Laden fehlgeschlagen',
        text: message,
        action: onRetry == null
            ? null
            : SecondaryButton(label: 'Erneut versuchen', icon: Icons.refresh, onPressed: onRetry),
      );
}

/// Platzhalter-Zeilen während des Ladens.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 8, this.rowHeight = 64});
  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        itemBuilder: (_, i) => SizedBox(
          height: rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Container(
                width: rowHeight - 20,
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 120.0 + (i * 37) % 90, height: 10, color: C.surface),
                    const SizedBox(height: 8),
                    Container(width: 80.0 + (i * 53) % 120, height: 8, color: C.surface),
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
}

void showUndo(BuildContext context, String text, VoidCallback undo) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(text),
    duration: const Duration(seconds: 6),
    action: SnackBarAction(label: 'Rückgängig', onPressed: undo),
  ));
}

void showInfo(BuildContext context, String text) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

String sectionIconLabel(Section s) => s.label;
