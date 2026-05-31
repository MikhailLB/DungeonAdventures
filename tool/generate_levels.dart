// Randomly searches for GENUINELY HARD puzzles: solvable, but NOT solvable by
// greedy "always push toward the goal" play, with a meaningful optimal length.
// Prints ready-to-paste _Raw(...) blocks sorted by optimal length.
//
// Run with:  dart run tool/generate_levels.dart [count] [seed]
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:dungeon_adventures/cartlock/models.dart';

import 'puzzle_solver.dart';

class Found {
  Found(this.layout, this.optimal, this.states, this.carts);
  final List<String> layout;
  final int optimal;
  final int states;
  final int carts;
}

void main(List<String> args) {
  final want = args.isNotEmpty ? int.parse(args[0]) : 24;
  final seed = args.length > 1 ? int.parse(args[1]) : 20260531;
  final rng = Random(seed);

  final found = <String, Found>{};
  const sizes = [
    [5, 6], [5, 7], [6, 6], [6, 7], [6, 8], [7, 7],
  ];

  var attempts = 0;
  while (found.length < want && attempts < 600000) {
    attempts++;
    final size = sizes[rng.nextInt(sizes.length)];
    final rows = size[0], cols = size[1];
    final nCarts = rng.nextInt(2) + 2; // 2..3
    final useRails = rng.nextBool();

    final layout = _randomLayout(rng, rows, cols, nCarts, useRails);
    if (layout == null) continue;

    LevelDef level;
    try {
      level = LevelDef.parse(id: 0, name: 'g', layout: layout, par: 1);
    } catch (_) {
      continue;
    }
    if (level.carts.length != nCarts || level.vaults.length != nCarts) continue;

    final a = analyze(level, stateCap: 260000);
    if (a.optimal == null) continue; // unsolvable
    if (a.states >= 260000) continue; // too big to be sure / slow
    if (a.greedy) continue; // trivially greedy -> skip
    if (a.optimal! < 9 || a.optimal! > 60) continue; // keep meaningful depth

    final key = layout.join('|');
    found.putIfAbsent(
        key, () => Found(layout, a.optimal!, a.states, nCarts));
  }

  final list = found.values.toList()
    ..sort((x, y) => x.optimal.compareTo(y.optimal));

  print('// Generated ${list.length} HARD puzzles in $attempts attempts '
      '(seed $seed)\n');
  var i = 0;
  for (final f in list) {
    i++;
    print("    _Raw($i, 'Gen $i', [");
    for (final row in f.layout) {
      print("      '$row',");
    }
    print('    ], ${f.optimal}), // carts=${f.carts} states=${f.states}');
  }
}

List<String>? _randomLayout(
    Random rng, int rows, int cols, int nCarts, bool useRails) {
  // grid of chars; border walls.
  final g = List.generate(rows, (r) => List<String>.filled(cols, '.'));
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      if (r == 0 || c == 0 || r == rows - 1 || c == cols - 1) g[r][c] = '#';
    }
  }

  final interior = <List<int>>[];
  for (int r = 1; r < rows - 1; r++) {
    for (int c = 1; c < cols - 1; c++) {
      interior.add([r, c]);
    }
  }

  // sprinkle internal walls
  final wallCount = rng.nextInt((interior.length * 0.28).round() + 1);
  for (int i = 0; i < wallCount; i++) {
    final cell = interior[rng.nextInt(interior.length)];
    g[cell[0]][cell[1]] = '#';
  }

  // collect remaining floor cells
  List<List<int>> floor() {
    final f = <List<int>>[];
    for (final cell in interior) {
      if (g[cell[0]][cell[1]] == '.') f.add(cell);
    }
    return f;
  }

  var open = floor();
  final need = 1 + nCarts * 2; // miner + carts + vaults
  if (open.length < need + 2) return null;

  // optional rails
  if (useRails) {
    final railCount = rng.nextInt((open.length * 0.4).round() + 1);
    for (int i = 0; i < railCount; i++) {
      final cell = open[rng.nextInt(open.length)];
      g[cell[0]][cell[1]] = '=';
    }
  }

  // place miner / carts / vaults on non-rail floor where sensible.
  open = <List<int>>[];
  final railable = <List<int>>[];
  for (final cell in interior) {
    final ch = g[cell[0]][cell[1]];
    if (ch == '.') open.add(cell);
    if (ch == '.' || ch == '=') railable.add(cell);
  }
  if (open.length < 1 + nCarts) return null;
  if (railable.length < nCarts) return null;

  open.shuffle(rng);
  railable.shuffle(rng);

  final miner = open.removeLast();
  g[miner[0]][miner[1]] = 'P';

  const cartCh = ['1', '2', '3'];
  const vaultCh = ['a', 'b', 'c'];

  // carts can sit on floor or rail
  final usedForCarts = <String>{};
  final cartCells = <List<int>>[];
  for (final cell in railable) {
    final ch = g[cell[0]][cell[1]];
    if (ch != '.' && ch != '=') continue;
    cartCells.add(cell);
    usedForCarts.add('${cell[0]},${cell[1]}');
    if (cartCells.length == nCarts) break;
  }
  if (cartCells.length < nCarts) return null;
  for (int i = 0; i < nCarts; i++) {
    final cell = cartCells[i];
    final wasRail = g[cell[0]][cell[1]] == '=';
    // carts on rail are written with their digit; rail under cart is lost in
    // our model (cart sits on floor), so only allow cart on rail if we keep it
    // simple: place cart on floor cells only to avoid ambiguity.
    if (wasRail) return null;
    g[cell[0]][cell[1]] = cartCh[i];
  }

  // vaults on remaining floor cells (not on carts/miner)
  final vaultCells = <List<int>>[];
  for (final cell in open) {
    if (usedForCarts.contains('${cell[0]},${cell[1]}')) continue;
    if (g[cell[0]][cell[1]] != '.') continue;
    vaultCells.add(cell);
    if (vaultCells.length == nCarts) break;
  }
  if (vaultCells.length < nCarts) return null;
  for (int i = 0; i < nCarts; i++) {
    final cell = vaultCells[i];
    g[cell[0]][cell[1]] = vaultCh[i];
  }

  return [for (final row in g) row.join()];
}
