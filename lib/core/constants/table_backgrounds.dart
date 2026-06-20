/// Selectable table backgrounds. Index 0 is the built-in painted table; the
/// rest are full-bleed images that REPLACE the painted felt. Gameplay and the
/// position of every UI element stay identical across backgrounds — only the
/// visuals change. Add new entries here (drop the image in assets/backgrounds/).
class TableBackground {
  final String name;

  /// null = use the built-in painter (classic). Otherwise an asset path that
  /// fills the table area (deck + felt + rail baked into the image).
  final String? asset;

  const TableBackground(this.name, this.asset);
}

const List<TableBackground> kTableBackgrounds = [
  TableBackground('Clásico', null),
  TableBackground('Tropical', 'assets/backgrounds/tropical.png'),
];
