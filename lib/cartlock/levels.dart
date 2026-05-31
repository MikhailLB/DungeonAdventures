import 'models.dart';

/// Hand-crafted levels for "Cart Lock", ordered by ascending difficulty.
///
/// Legend:
///   # wall   . floor   = rail   T torch   P miner
///   1/2/3 carts (amber/azure/gold)   a/b/c vaults (amber/azure/gold)
///
/// Levels 1-3 teach the rules. Levels 4+ are verified by tool/solve_levels.dart
/// to be NON-greedy: they cannot be solved by simply pushing each cart toward
/// its vault. You must move a cart AWAY from its goal (to clear a path or free
/// a blocker) before the puzzle opens up. par = optimal move count.
final List<LevelDef> kLevels = _build();

List<LevelDef> _build() {
  final raw = <_Raw>[
    // ── TUTORIAL ──────────────────────────────────────────────
    _Raw(1, 'First Glide', [
      '#######',
      '#.....#',
      '#P1==a#',
      '#.....#',
      '#######',
    ], 1),
    _Raw(2, 'The Shaft', [
      '#######',
      '#.....#',
      '#.a...#',
      '#.=...#',
      '#.1...#',
      '#P....#',
      '#######',
    ], 2),
    _Raw(3, 'Nudge', [
      '#######',
      '#a....#',
      '#.....#',
      '#.1...#',
      '#..P..#',
      '#######',
    ], 6),

    // ── REAL PUZZLES (non-greedy, auto-verified) ──────────────
    _Raw(4, 'Loop', [
      '#######',
      '##=.b.#',
      '#..2=.#',
      '#..1P##',
      '#..a..#',
      '#.....#',
      '#######',
    ], 11),
    _Raw(5, 'Bypass', [
      '########',
      '#..=.=.#',
      '#=.....#',
      '#.2.=.1#',
      '#P.#b.a#',
      '########',
    ], 12),
    _Raw(6, 'Sidetrack', [
      '#######',
      '#...#.#',
      '#.P.2.#',
      '#1=.b=#',
      '#a#..=#',
      '#.=#=.#',
      '#######',
    ], 14),
    _Raw(7, 'Nook', [
      '#######',
      '#.#...#',
      '#..2Pb#',
      '#.a.1.#',
      '#######',
    ], 16),
    _Raw(8, 'Fork', [
      '########',
      '#b..2..#',
      '#..1...#',
      '##.#.#.#',
      '#Pa#...#',
      '########',
    ], 18),
    _Raw(9, 'Hook', [
      '#######',
      '#b...P#',
      '#.#.1.#',
      '#.2..a#',
      '##....#',
      '#######',
    ], 19),
    _Raw(10, 'Wedge', [
      '#######',
      '#.....#',
      '#...1a#',
      '#bP2###',
      '#.....#',
      '#.#...#',
      '#######',
    ], 20),
    _Raw(11, 'Cellar', [
      '#######',
      '#...#.#',
      '#a.P2.#',
      '#..1b.#',
      '#....##',
      '##..#.#',
      '#######',
    ], 21),
    _Raw(12, 'Crook', [
      '#######',
      '#.=a.##',
      '###2..#',
      '#.=1..#',
      '#.bP..#',
      '#######',
    ], 22),
    _Raw(13, 'Cradle', [
      '#######',
      '#.#==b#',
      '#.1...#',
      '#a...=#',
      '#.2.==#',
      '#..P..#',
      '#######',
    ], 23),
    _Raw(14, 'Slipway', [
      '#######',
      '#..=.a#',
      '##P.2##',
      '#=b.1=#',
      '#..=..#',
      '#######',
    ], 24),
    _Raw(15, 'Triad', [
      '########',
      '#.#.==.#',
      '#b1a..3#',
      '#.2#.=c#',
      '#P...###',
      '########',
    ], 25),
    _Raw(16, 'Pocket', [
      '#######',
      '#Pa.###',
      '#.1.2=#',
      '#...b.#',
      '#######',
    ], 26),
    _Raw(17, 'Ravine', [
      '#######',
      '#a..b.#',
      '#.1P..#',
      '###.2.#',
      '#....##',
      '#######',
    ], 27),
    _Raw(18, 'Switch', [
      '########',
      '#=..=.##',
      '#=.2.=.#',
      '#.1P#..#',
      '##.ba..#',
      '########',
    ], 28),
    _Raw(19, 'Deadlock', [
      '#######',
      '#.P...#',
      '##1..a#',
      '#.....#',
      '#.b2..#',
      '#######',
    ], 30),
    _Raw(20, 'Trident', [
      '########',
      '#....#.#',
      '#a..2..#',
      '#1.b.#.#',
      '#c.P.3.#',
      '########',
    ], 30),
    _Raw(21, 'Gambit', [
      '########',
      '#.#..b.#',
      '#..#.a.#',
      '#..12.P#',
      '#......#',
      '########',
    ], 35),
    _Raw(22, 'Maze', [
      '########',
      '#b...#.#',
      '#..2#..#',
      '#.P1..##',
      '#...a..#',
      '########',
    ], 36),
    _Raw(23, 'Snare', [
      '#######',
      '#.P.#.#',
      '#.....#',
      '#.#2b.#',
      '#.1a.##',
      '#.#...#',
      '#######',
    ], 37),
    _Raw(24, 'Labyrinth', [
      '#######',
      '#.b.a.#',
      '#.2.#.#',
      '#.....#',
      '#..#1.#',
      '#..P.##',
      '#######',
    ], 40),
    _Raw(25, 'Rail Knot', [
      '#######',
      '#.#=.b#',
      '##=.#=#',
      '###2.=#',
      '#.P.1.#',
      '#==a.##',
      '#######',
    ], 42),
    _Raw(26, 'Warden', [
      '#######',
      '#.....#',
      '#..1#.#',
      '#a..#.#',
      '#.b2..#',
      '#P..#.#',
      '#######',
    ], 43),
    _Raw(27, 'Crypt', [
      '#######',
      '#.....#',
      '#a.b#.#',
      '##.12.#',
      '#...P.#',
      '#######',
    ], 46),
    _Raw(28, 'Oubliette', [
      '#######',
      '#.#...#',
      '##.a2b#',
      '#.P.1##',
      '#.....#',
      '#######',
    ], 47),
    _Raw(29, "Keeper's Trial", [
      '########',
      '#b.....#',
      '#P..1#.#',
      '#a#..2.#',
      '#...#..#',
      '########',
    ], 56),
  ];

  return raw.map((r) {
    final layout = r.layout
        .map((line) => line.replaceAll('+', '='))
        .toList(growable: false);
    return LevelDef.parse(
      id: r.id,
      name: r.name,
      layout: layout,
      par: r.par,
    );
  }).toList(growable: false);
}

class _Raw {
  const _Raw(this.id, this.name, this.layout, this.par);
  final int id;
  final String name;
  final List<String> layout;
  final int par;
}
