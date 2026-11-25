import 'package:flutter/material.dart';

/// Farben aus dem Design (dunkel, Video im Mittelpunkt, Mint-Akzent).
class C {
  static const bg = Color(0xFF0B0C0F);
  static const sidebar = Color(0xFF111318);
  static const surface = Color(0xFF171A20);
  static const surfaceHi = Color(0xFF1E222A);
  static const surfaceSel = Color(0xFF1A1E25);
  static const field = Color(0xFF0F1115);
  static const border = Color(0xFF22262E);
  static const border2 = Color(0xFF2C313B);
  static const text = Color(0xFFF2F4F7);
  static const text2 = Color(0xFFC9CED8);
  static const muted = Color(0xFF9AA3B2);
  static const faint = Color(0xFF8A93A3);
  static const track = Color(0xFF262A33);
  static const accent = Color(0xFF3EE0B0);
  static const onAccent = Color(0xFF0B0C0F);
  static const live = Color(0xFFFF5A5F);
  static const star = Color(0xFFF5B942);
  static const ok = Color(0xFF3DDC84);
  static const warn = Color(0xFFF5B942);
  static const overlay = Color(0x99000000);
  static const glass = Color(0x1FFFFFFF);

  static const listColors = [
    0xFF7AA7FF,
    0xFFF08BD0,
    0xFF3EE0B0,
    0xFFFF7A59,
    0xFFB98CFF,
    0xFFF5B942,
  ];
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: C.accent,
    onPrimary: C.onAccent,
    secondary: C.accent,
    surface: C.surface,
    onSurface: C.text,
    error: C.live,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    canvasColor: C.bg,
    dividerColor: C.border,
    splashFactory: NoSplash.splashFactory,
    visualDensity: VisualDensity.standard,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.text, displayColor: C.text),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: C.surfaceHi, borderRadius: BorderRadius.all(Radius.circular(6))),
      textStyle: TextStyle(color: C.text, fontSize: 12),
      waitDuration: Duration(milliseconds: 500),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: C.surfaceHi,
      contentTextStyle: TextStyle(color: C.text, fontSize: 14),
      actionTextColor: C.accent,
      behavior: SnackBarBehavior.floating,
      width: 460,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF14161B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: Color(0xFF262A33)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: C.surfaceHi,
      textStyle: TextStyle(color: C.text, fontSize: 14),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.dragged)
            ? C.accent
            : s.contains(WidgetState.hovered)
                ? const Color(0xFF4A5160)
                : C.border2,
      ),
      thickness: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.hovered) || s.contains(WidgetState.dragged) ? 10 : 6,
      ),
      trackVisibility: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered)),
      trackColor: const WidgetStatePropertyAll(Color(0x0DFFFFFF)),
      trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      radius: const Radius.circular(5),
      interactive: true,
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: C.accent,
      inactiveTrackColor: C.track,
      thumbColor: C.text,
      overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      trackHeight: 4,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: C.field,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      hintStyle: TextStyle(color: C.faint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: C.border2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: C.border2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: C.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: C.live),
      ),
    ),
  );
}
