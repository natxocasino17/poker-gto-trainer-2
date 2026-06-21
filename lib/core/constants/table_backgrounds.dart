/// Selectable table backgrounds. Index 0 is the built-in painted table; the
/// rest are full-bleed images that REPLACE the painted felt. Gameplay and the
/// position of every UI element stay identical across backgrounds — only the
/// visuals change. Add new entries here (drop the image in assets/backgrounds/).
class TableBackground {
  final String name;

  /// null = use the built-in painter (classic). Otherwise an asset path that
  /// fills the table area (deck + felt + rail baked into the image).
  final String? asset;

  /// Felt-width factor relative to the standard image table (1.0). Lower for
  /// narrower felts (pull chips/dealer inward), higher for wider ones, so the
  /// bet chips and dealer button always sit ON the felt.
  final double scale;

  const TableBackground(this.name, this.asset, {this.scale = 1.0});
}

const List<TableBackground> kTableBackgrounds = [
  TableBackground('Clásico', null),
  TableBackground('Tropical', 'assets/backgrounds/tropical.png'),
  TableBackground('Neón', 'assets/backgrounds/neon.png'),
  TableBackground('Lujo', 'assets/backgrounds/luxury.png'),
  TableBackground('Terciopelo', 'assets/backgrounds/bg1.png', scale: 0.85),
  TableBackground('Minimal', 'assets/backgrounds/bg2.png', scale: 0.80),
  TableBackground('Saloon', 'assets/backgrounds/bg3.png', scale: 1.05),
  TableBackground('Espacial', 'assets/backgrounds/bg4.png', scale: 0.82),
  TableBackground('Yate', 'assets/backgrounds/bg5.png', scale: 0.98),
  TableBackground('Arcade', 'assets/backgrounds/bg6.png', scale: 1.08),
  TableBackground('Steampunk', 'assets/backgrounds/bg7.png', scale: 0.92),
];
