import 'models.dart';

enum MoveDir { up, down, left, right }

extension on MoveDir {
  int get dRow {
    switch (this) {
      case MoveDir.up:
        return -1;
      case MoveDir.down:
        return 1;
      default:
        return 0;
    }
  }

  int get dCol {
    switch (this) {
      case MoveDir.left:
        return -1;
      case MoveDir.right:
        return 1;
      default:
        return 0;
    }
  }
}

class Cart {
  Cart({required this.color, required this.pos}) : prevPos = pos;

  final CartColor color;
  GridPos pos;
  GridPos prevPos;

  bool onTarget(LevelDef level) => level.vaultColorAt(pos) == color;
}

class _Snapshot {
  _Snapshot(this.minerPos, this.cartPositions, this.moveCount);

  final GridPos minerPos;
  final List<GridPos> cartPositions;
  final int moveCount;
}

/// Pure puzzle logic. No Flutter dependencies; the play screen drives rendering
/// and animation from this state.
class PuzzleEngine {
  PuzzleEngine(this.level) {
    reset();
  }

  final LevelDef level;

  late GridPos minerPos;
  late GridPos minerPrevPos;
  late List<Cart> carts;
  int moveCount = 0;

  /// -1 facing left, 1 facing right, 0 neutral. Used to flip the sprite.
  int facing = 1;

  /// True once all carts rest on matching vaults.
  bool solved = false;

  final List<_Snapshot> _undoStack = <_Snapshot>[];

  bool get canUndo => _undoStack.isNotEmpty;

  void reset() {
    minerPos = level.minerStart;
    minerPrevPos = level.minerStart;
    carts = level.carts
        .map((spawn) => Cart(color: spawn.color, pos: spawn.pos))
        .toList();
    moveCount = 0;
    facing = 1;
    solved = false;
    _undoStack.clear();
  }

  Cart? _cartAt(GridPos p) {
    for (final cart in carts) {
      if (cart.pos == p) {
        return cart;
      }
    }
    return null;
  }

  bool _isBlockedForMiner(GridPos p) {
    if (!level.inBounds(p)) {
      return true;
    }
    final t = level.tileAt(p);
    return t == TileType.wall || t == TileType.torch;
  }

  bool _isBlockedForCart(GridPos p) {
    if (!level.inBounds(p)) {
      return true;
    }
    final t = level.tileAt(p);
    if (t == TileType.wall || t == TileType.torch) {
      return true;
    }
    return _cartAt(p) != null;
  }

  /// Attempts a move in [dir]. Returns true if anything changed (so the UI can
  /// trigger the step animation). Solving is re-evaluated after each move.
  bool move(MoveDir dir) {
    if (solved) {
      return false;
    }

    if (dir == MoveDir.left) {
      facing = -1;
    } else if (dir == MoveDir.right) {
      facing = 1;
    }

    final target = minerPos.translate(dir.dRow, dir.dCol);
    if (_isBlockedForMiner(target)) {
      return false;
    }

    final cart = _cartAt(target);
    if (cart != null) {
      final next = cart.pos.translate(dir.dRow, dir.dCol);
      if (_isBlockedForCart(next)) {
        // Cart can't move, so the miner can't push into it.
        return false;
      }
    }

    // The move will succeed: snapshot for undo and clear stale animation
    // origins so only the entities that actually move will tween.
    final snapshot = _capture();
    for (final c in carts) {
      c.prevPos = c.pos;
    }

    if (cart != null) {
      _slideCart(cart, dir);
    }

    // Miner steps into the (now vacated) target cell.
    minerPrevPos = minerPos;
    minerPos = target;
    moveCount += 1;

    _undoStack.add(snapshot);
    _evaluateSolved();
    return true;
  }

  /// Moves the cart one cell, then keeps gliding while it sits on a rail tile
  /// and the next cell is free.
  void _slideCart(Cart cart, MoveDir dir) {
    cart.prevPos = cart.pos;
    var current = cart.pos.translate(dir.dRow, dir.dCol);
    cart.pos = current;

    while (level.tileAt(current) == TileType.rail) {
      final next = current.translate(dir.dRow, dir.dCol);
      if (_isBlockedForCart(next)) {
        break;
      }
      current = next;
      cart.pos = current;
    }
  }

  _Snapshot _capture() {
    return _Snapshot(
      minerPos,
      carts.map((c) => c.pos).toList(),
      moveCount,
    );
  }

  void undo() {
    if (_undoStack.isEmpty) {
      return;
    }
    final snap = _undoStack.removeLast();
    minerPos = snap.minerPos;
    minerPrevPos = snap.minerPos;
    for (int i = 0; i < carts.length; i++) {
      carts[i].pos = snap.cartPositions[i];
      carts[i].prevPos = snap.cartPositions[i];
    }
    moveCount = snap.moveCount;
    solved = false;
  }

  void _evaluateSolved() {
    for (final cart in carts) {
      if (!cart.onTarget(level)) {
        solved = false;
        return;
      }
    }
    solved = true;
  }

  /// 3 stars at or under par, 2 stars within 1.5x par, otherwise 1 star.
  int starsForMoves(int moves) {
    if (moves <= level.par) {
      return 3;
    }
    if (moves <= (level.par * 1.5).ceil()) {
      return 2;
    }
    return 1;
  }

  int get earnedStars => solved ? starsForMoves(moveCount) : 0;
}
