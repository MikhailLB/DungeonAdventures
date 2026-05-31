// Validates every level: solvable, par == optimal, and whether it is a real
// puzzle (HARD) or trivially solvable by always pushing toward the goal
// (EASY-greedy).
//
// Run with:  dart run tool/solve_levels.dart
// ignore_for_file: avoid_print
import 'package:dungeon_adventures/cartlock/levels.dart';
import 'package:dungeon_adventures/cartlock/models.dart';

import 'puzzle_solver.dart';

void main() {
  var allOk = true;
  var easyCount = 0;
  for (final level in kLevels) {
    final cartCounts = <CartColor, int>{};
    final vaultCounts = <CartColor, int>{};
    for (final cart in level.carts) {
      cartCounts[cart.color] = (cartCounts[cart.color] ?? 0) + 1;
    }
    for (final v in level.vaults) {
      vaultCounts[v.color] = (vaultCounts[v.color] ?? 0) + 1;
    }
    bool mismatch = false;
    for (final color in CartColor.values) {
      if ((cartCounts[color] ?? 0) != (vaultCounts[color] ?? 0)) mismatch = true;
    }

    final a = analyze(level);
    final solvable = a.optimal != null && !mismatch;
    if (!solvable) allOk = false;
    if (a.greedy) easyCount++;
    final flag = a.optimal == null
        ? 'UNSOLVABLE'
        : (mismatch ? 'COUNT-MISMATCH' : (a.greedy ? 'EASY-greedy' : 'HARD'));
    final mark = a.optimal != null && !mismatch && a.optimal != level.par
        ? ' (par should be ${a.optimal})'
        : '';
    print(
      'L${level.id.toString().padLeft(2)} ${level.name.padRight(16)} '
      'opt=${(a.optimal ?? "-").toString().padLeft(3)} '
      'par=${level.par.toString().padLeft(3)} '
      'states=${a.states.toString().padLeft(7)}  $flag$mark',
    );
  }
  print('\n${allOk ? "ALL SOLVABLE" : "NEEDS FIXES"}  -  '
      '$easyCount/${kLevels.length} are EASY-greedy');
}
