import 'dart:ui' as ui;

enum CartType { trolley1, trolley2, trolley3 }

enum DecoType { tree, torch }

class GameAssets {
  static final GameAssets _instance = GameAssets._();
  factory GameAssets() => _instance;
  GameAssets._();

  bool loaded = false;

  late ui.Image gameName;
  late ui.Image logo;

  late ui.Image turkeyAlive;
  late ui.Image turkeyDead;
  late ui.Image turkeyFired;

  late ui.Image trolley1;
  late ui.Image trolley2;
  late ui.Image trolley3;

  late ui.Image bgStart;
  late ui.Image bgSafe;
  late ui.Image bgSafeAlt;
  late ui.Image bgRail;
  late ui.Image bgRailAlt;
  late ui.Image bgRailMix;
  late ui.Image bgRailIsland;

  late ui.Image tree;
  late ui.Image tree2;
  late ui.Image tree3;
  late ui.Image torch;
  late ui.Image torchAlt;

  static const _paths = [
    'assets/title.webp',                   // 0
    'assets/assets/logo.webp',             // 1
    'assets/assets/player.webp',           // 2
    'assets/assets/player_dead.webp',      // 3
    'assets/assets/player_fired.webp',     // 4
    'assets/assets/cart_1.webp',           // 5
    'assets/assets/cart_2.webp',           // 6
    'assets/assets/cart_3.webp',           // 7
    'assets/assets/bg_start.webp',         // 8
    'assets/assets/bg_island.webp',        // 9
    'assets/assets/bg_islands.webp',       // 10
    'assets/assets/bg_rail.webp',          // 11
    'assets/assets/bg_rail_alt.webp',      // 12
    'assets/assets/bg_rail_mix.webp',      // 13
    'assets/assets/bg_rail_island.webp',   // 14
    'assets/assets/tree_1.webp',           // 15
    'assets/assets/tree_2.webp',           // 16
    'assets/assets/tree_3.webp',           // 17
    'assets/assets/torch_1.webp',          // 18
    'assets/assets/torch_2.webp',          // 19
  ];

  Future<void> loadAll({void Function(int done, int total)? onProgress}) async {
    if (loaded) return;

    int done = 0;
    final total = _paths.length;

    Future<ui.Image> loadOne(String path) async {
      final img = await _load(path);
      onProgress?.call(++done, total);
      return img;
    }

    final results = await Future.wait<ui.Image>(
      _paths.map(loadOne),
    );

    gameName     = results[0];
    logo         = results[1];
    turkeyAlive  = results[2];
    turkeyDead   = results[3];
    turkeyFired  = results[4];
    trolley1     = results[5];
    trolley2     = results[6];
    trolley3     = results[7];
    bgStart      = results[8];
    bgSafe       = results[9];
    bgSafeAlt    = results[10];
    bgRail       = results[11];
    bgRailAlt    = results[12];
    bgRailMix    = results[13];
    bgRailIsland = results[14];
    tree         = results[15];
    tree2        = results[16];
    tree3        = results[17];
    torch        = results[18];
    torchAlt     = results[19];
    loaded = true;
  }

  ui.Image cartImage(CartType type) {
    switch (type) {
      case CartType.trolley1:
        return trolley1;
      case CartType.trolley2:
        return trolley2;
      case CartType.trolley3:
        return trolley3;
    }
  }

  ui.Image treeImage(int variant) {
    switch (variant % 3) {
      case 1:
        return tree2;
      case 2:
        return tree3;
      default:
        return tree;
    }
  }

  ui.Image torchImage(bool alternate) => alternate ? torchAlt : torch;

  /// Decodes via ImmutableBuffer — avoids the extra Uint8List copy that
  /// rootBundle.load() + instantiateImageCodec() would produce.
  Future<ui.Image> _load(String path) async {
    final buffer = await ui.ImmutableBuffer.fromAsset(path);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final codec = await descriptor.instantiateCodec();
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
