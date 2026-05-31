// Shared puzzle-analysis core used by solve_levels.dart and generate_levels.dart.
import 'dart:collection';

import 'package:dungeon_adventures/cartlock/models.dart';

const List<List<int>> dirs = [
  [-1, 0],
  [1, 0],
  [0, -1],
  [0, 1],
];

bool blockedForMiner(LevelDef level, int r, int c) {
  if (r < 0 || r >= level.rows || c < 0 || c >= level.cols) return true;
  final t = level.tiles[r][c];
  return t == TileType.wall || t == TileType.torch;
}

bool blockedForCart(LevelDef level, int r, int c, List<int> carts) {
  if (r < 0 || r >= level.rows || c < 0 || c >= level.cols) return true;
  final t = level.tiles[r][c];
  if (t == TileType.wall || t == TileType.torch) return true;
  for (int i = 0; i < carts.length; i += 2) {
    if (carts[i] == r && carts[i + 1] == c) return true;
  }
  return false;
}

int? cartIndexAt(List<int> carts, int r, int c) {
  for (int i = 0; i < carts.length; i += 2) {
    if (carts[i] == r && carts[i + 1] == c) return i;
  }
  return null;
}

String stateKey(int mr, int mc, List<int> carts) => '$mr,$mc|${carts.join(',')}';

bool isSolved(LevelDef level, List<int> carts) {
  for (int i = 0; i < carts.length; i += 2) {
    final color = level.carts[i ~/ 2].color;
    if (level.vaultColorAt(GridPos(carts[i], carts[i + 1])) != color) {
      return false;
    }
  }
  return true;
}

/// Apply a move; returns [mr, mc, carts] or null when blocked.
List<dynamic>? apply(
    LevelDef level, int mr, int mc, List<int> carts, List<int> d) {
  final tr = mr + d[0];
  final tc = mc + d[1];
  if (blockedForMiner(level, tr, tc)) return null;
  final next = List<int>.from(carts);
  final ci = cartIndexAt(next, tr, tc);
  if (ci != null) {
    int cr = tr, cc = tc;
    final nr = cr + d[0], nc = cc + d[1];
    if (blockedForCart(level, nr, nc, next)) return null;
    cr = nr;
    cc = nc;
    while (level.tiles[cr][cc] == TileType.rail) {
      final sr = cr + d[0], sc = cc + d[1];
      if (blockedForCart(level, sr, sc, next)) break;
      cr = sr;
      cc = sc;
    }
    next[ci] = cr;
    next[ci + 1] = cc;
  }
  return [tr, tc, next];
}

List<int> startCartsOf(LevelDef level) {
  final c = <int>[];
  for (final cart in level.carts) {
    c
      ..add(cart.pos.row)
      ..add(cart.pos.col);
  }
  return c;
}

class Analysis {
  Analysis(this.optimal, this.states, this.dead, this.greedy);
  final int? optimal;
  final int states;
  final int dead;
  final bool greedy;
}

/// Forward BFS for the optimal length, reachable state count and dead
/// (soft-locked) state count.
Analysis analyze(LevelDef level, {int stateCap = 1200000}) {
  final start = startCartsOf(level);
  final dist = HashMap<String, int>();
  final adj = HashMap<String, List<String>>();
  final solved = <String>[];
  final q = Queue<List<dynamic>>();
  final startKey = stateKey(level.minerStart.row, level.minerStart.col, start);
  dist[startKey] = 0;
  q.add([level.minerStart.row, level.minerStart.col, start]);
  int? optimal;
  if (isSolved(level, start)) optimal = 0;

  while (q.isNotEmpty) {
    if (dist.length > stateCap) break;
    final node = q.removeFirst();
    final mr = node[0] as int, mc = node[1] as int;
    final carts = node[2] as List<int>;
    final key = stateKey(mr, mc, carts);
    final neigh = <String>[];
    for (final d in dirs) {
      final res = apply(level, mr, mc, carts, d);
      if (res == null) continue;
      final nr = res[0] as int, nc = res[1] as int;
      final ncarts = res[2] as List<int>;
      final nkey = stateKey(nr, nc, ncarts);
      neigh.add(nkey);
      if (!dist.containsKey(nkey)) {
        dist[nkey] = dist[key]! + 1;
        if (isSolved(level, ncarts)) {
          optimal ??= dist[nkey];
          solved.add(nkey);
        }
        q.add([nr, nc, ncarts]);
      }
    }
    adj[key] = neigh;
  }

  final reverse = HashMap<String, List<String>>();
  for (final e in adj.entries) {
    for (final n in e.value) {
      (reverse[n] ??= <String>[]).add(e.key);
    }
  }
  final live = HashSet<String>();
  final rq = Queue<String>();
  for (final s in solved) {
    if (live.add(s)) rq.add(s);
  }
  while (rq.isNotEmpty) {
    final s = rq.removeFirst();
    for (final p in reverse[s] ?? const <String>[]) {
      if (live.add(p)) rq.add(p);
    }
  }
  return Analysis(optimal, dist.length, dist.length - live.length,
      greedySolvable(level));
}

List<List<int>> distMap(LevelDef level, GridPos goal) {
  final dist =
      List.generate(level.rows, (_) => List<int>.filled(level.cols, 1 << 30));
  final q = Queue<GridPos>();
  dist[goal.row][goal.col] = 0;
  q.add(goal);
  while (q.isNotEmpty) {
    final p = q.removeFirst();
    for (final d in dirs) {
      final r = p.row + d[0], c = p.col + d[1];
      if (r < 0 || r >= level.rows || c < 0 || c >= level.cols) continue;
      final t = level.tiles[r][c];
      if (t == TileType.wall || t == TileType.torch) continue;
      if (dist[r][c] != 1 << 30) continue;
      dist[r][c] = dist[p.row][p.col] + 1;
      q.add(GridPos(r, c));
    }
  }
  return dist;
}

int heuristic(LevelDef level, List<int> carts, List<List<List<int>>> vaultDist) {
  int total = 0;
  for (int i = 0; i < carts.length; i += 2) {
    final color = level.carts[i ~/ 2].color;
    int best = 1 << 30;
    for (int v = 0; v < level.vaults.length; v++) {
      if (level.vaults[v].color != color) continue;
      final d = vaultDist[v][carts[i]][carts[i + 1]];
      if (d < best) best = d;
    }
    total += best;
  }
  return total;
}

/// True if the level can be solved while never increasing the wall-aware total
/// cart-to-goal distance (a naive "always push toward the goal" player wins).
bool greedySolvable(LevelDef level) {
  final vaultDist = [for (final v in level.vaults) distMap(level, v.pos)];
  final start = startCartsOf(level);
  final visited = HashSet<String>();
  final q = Queue<List<dynamic>>();
  final startH = heuristic(level, start, vaultDist);
  q.add([level.minerStart.row, level.minerStart.col, start, startH]);
  visited.add(stateKey(level.minerStart.row, level.minerStart.col, start));
  if (isSolved(level, start)) return true;
  while (q.isNotEmpty) {
    final node = q.removeFirst();
    final mr = node[0] as int, mc = node[1] as int;
    final carts = node[2] as List<int>;
    final curH = node[3] as int;
    for (final d in dirs) {
      final res = apply(level, mr, mc, carts, d);
      if (res == null) continue;
      final nr = res[0] as int, nc = res[1] as int;
      final ncarts = res[2] as List<int>;
      final nh = heuristic(level, ncarts, vaultDist);
      if (nh > curH) continue;
      final nkey = stateKey(nr, nc, ncarts);
      if (!visited.add(nkey)) continue;
      if (isSolved(level, ncarts)) return true;
      q.add([nr, nc, ncarts, nh]);
    }
  }
  return false;
}
