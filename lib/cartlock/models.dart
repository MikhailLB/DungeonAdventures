/// Core data model for the "Cart Lock" puzzle.
///
/// A level is authored as an ASCII grid. The legend:
///   '#'  wall (impassable border / blocks)
///   '.'  floor (miner walks; a cart pushed onto floor stops after 1 cell)
///   '='  rail  (a cart pushed onto rail glides until something blocks it)
///   'T'  torch (immovable bumper that blocks miner and carts)
///   'P'  miner start position (stands on a floor tile)
///   '1'  amber cart (cart_1)   sits on a floor/rail tile
///   '2'  azure cart (cart_2)
///   '3'  gold  cart (cart_3)
///   'a'  amber vault (target for cart 1)
///   'b'  azure vault (target for cart 2)
///   'c'  gold  vault (target for cart 3)
///
/// A tile can hold a vault marker AND host a cart at start, so carts/vaults are
/// parsed into separate layers from the same grid character.
library;

enum TileType { wall, floor, rail, torch }

enum CartColor { amber, azure, gold }

class GridPos {
  const GridPos(this.row, this.col);

  final int row;
  final int col;

  GridPos translate(int dRow, int dCol) => GridPos(row + dRow, col + dCol);

  @override
  bool operator ==(Object other) =>
      other is GridPos && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => '($row,$col)';
}

class CartSpawn {
  const CartSpawn(this.color, this.pos);

  final CartColor color;
  final GridPos pos;
}

class VaultSpawn {
  const VaultSpawn(this.color, this.pos);

  final CartColor color;
  final GridPos pos;
}

/// An immutable, parsed level definition.
class LevelDef {
  LevelDef({
    required this.id,
    required this.name,
    required this.rows,
    required this.cols,
    required this.tiles,
    required this.minerStart,
    required this.carts,
    required this.vaults,
    required this.par,
  });

  final int id;
  final String name;
  final int rows;
  final int cols;

  /// [row][col] tile types.
  final List<List<TileType>> tiles;
  final GridPos minerStart;
  final List<CartSpawn> carts;
  final List<VaultSpawn> vaults;

  /// Move count for a 3-star clear. 2 stars at par+a few, 1 star for any clear.
  final int par;

  TileType tileAt(GridPos p) => tiles[p.row][p.col];

  bool inBounds(GridPos p) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  CartColor? vaultColorAt(GridPos p) {
    for (final v in vaults) {
      if (v.pos == p) {
        return v.color;
      }
    }
    return null;
  }

  /// Parse a level from an ASCII layout. Each string is a grid row; all rows
  /// must share the same length.
  static LevelDef parse({
    required int id,
    required String name,
    required List<String> layout,
    required int par,
  }) {
    assert(layout.isNotEmpty, 'Level $id has empty layout');
    final rows = layout.length;
    final cols = layout.first.length;

    final tiles = <List<TileType>>[];
    final carts = <CartSpawn>[];
    final vaults = <VaultSpawn>[];
    GridPos? minerStart;

    for (int r = 0; r < rows; r++) {
      final line = layout[r];
      if (line.length != cols) {
        throw StateError(
          'Level $id row $r has length ${line.length}, expected $cols: "$line"',
        );
      }
      final tileRow = <TileType>[];
      for (int c = 0; c < cols; c++) {
        final ch = line[c];
        final pos = GridPos(r, c);
        switch (ch) {
          case '#':
            tileRow.add(TileType.wall);
            break;
          case 'T':
            tileRow.add(TileType.torch);
            break;
          case '=':
            tileRow.add(TileType.rail);
            break;
          case '1':
          case '2':
          case '3':
            tileRow.add(TileType.floor);
            carts.add(CartSpawn(_cartColorFor(ch), pos));
            break;
          case 'a':
          case 'b':
          case 'c':
            tileRow.add(TileType.floor);
            vaults.add(VaultSpawn(_vaultColorFor(ch), pos));
            break;
          // A cart sitting on a rail vault: uppercase variants land the cart on
          // a rail tile that is also a target. We support combined tokens below.
          case 'A':
          case 'B':
          case 'C':
            tileRow.add(TileType.rail);
            carts.add(CartSpawn(_cartColorForUpper(ch), pos));
            break;
          case 'P':
            tileRow.add(TileType.floor);
            minerStart = pos;
            break;
          case '.':
          default:
            tileRow.add(TileType.floor);
            break;
        }
      }
      tiles.add(tileRow);
    }

    if (minerStart == null) {
      throw StateError('Level $id is missing miner start (P)');
    }

    return LevelDef(
      id: id,
      name: name,
      rows: rows,
      cols: cols,
      tiles: tiles,
      minerStart: minerStart,
      carts: carts,
      vaults: vaults,
      par: par,
    );
  }

  static CartColor _cartColorFor(String ch) {
    switch (ch) {
      case '1':
        return CartColor.amber;
      case '2':
        return CartColor.azure;
      default:
        return CartColor.gold;
    }
  }

  static CartColor _cartColorForUpper(String ch) {
    switch (ch) {
      case 'A':
        return CartColor.amber;
      case 'B':
        return CartColor.azure;
      default:
        return CartColor.gold;
    }
  }

  static CartColor _vaultColorFor(String ch) {
    switch (ch) {
      case 'a':
        return CartColor.amber;
      case 'b':
        return CartColor.azure;
      default:
        return CartColor.gold;
    }
  }
}
