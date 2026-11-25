# noAd IPTV Player

Schlanker, werbefreier IPTV-Player für **Xtream Codes** und **M3U** – Windows und macOS, gebaut mit Flutter und libmpv (über [media_kit](https://github.com/media-kit/media-kit)). Kein VLC nötig.

## Funktionen

- Mehrere Quellen gleichzeitig: Xtream-Zugänge, M3U-Links und M3U-Dateien
- Live-TV, Filme und Serien (mit Staffeln/Episoden)
- Suche über alle Quellen (Strg/⌘ + K)
- Favoriten und eigene Listen aus beliebigen Quellen, per Ziehen sortierbar
- „Weiterschauen“ – merkt sich die Position bei Filmen und Episoden
- Vollbild mit automatisch ausblendender Steuerung

## Tastenkürzel

| Taste | Aktion |
|---|---|
| Leertaste | Pause / Weiter |
| F | Vollbild |
| Esc | Vollbild beenden |
| ↑ / ↓ | Vorheriger / nächster Sender |
| ← / → | 10 s zurück / vor (Filme) |
| Z | Senderliste im Vollbild |
| Strg/⌘ + K | Suche |

## Herunterladen

Fertige Builds: **Actions → letzter „Build“-Lauf → Artifacts** (`noAd-IPTV-Windows-Setup`, `noAd-IPTV-macOS`).
Bei einem Tag `v*` entsteht automatisch ein Release.

## Lokal entwickeln (macOS)

```bash
flutter pub get
flutter run -d macos
```

Die macOS-App ist nicht signiert: beim ersten Start Rechtsklick → „Öffnen“.
