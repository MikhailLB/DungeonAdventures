import 'dart:ui' as ui;
import 'package:flutter/services.dart';

import 'models.dart';
import 'skins.dart';

/// Loads and caches every decoded image the puzzle renderer needs. Singleton so
/// the bootstrap flow can warm it once and the painter can read synchronously.
class GameAssets {
  static final GameAssets _instance = GameAssets._();
  factory GameAssets() => _instance;
  GameAssets._();

  bool loaded = false;

  late ui.Image title;
  late ui.Image logo;

  // Carts by color.
  late ui.Image cartAmber; // cart_1
  late ui.Image cartAzure; // cart_2
  late ui.Image cartGold; // cart_3

  // Tiles / backdrops.
  late ui.Image tileFloor; // bg_island
  late ui.Image tileRail; // bg_rail
  late ui.Image bgStart;
  late ui.Image bgIslands; // tall menu backdrop
  late ui.Image bgRailAlt; // tall menu backdrop

  // Props.
  late ui.Image torch; // torch_1
  late ui.Image torchAlt; // torch_2
  late ui.Image tree1;
  late ui.Image tree2;
  late ui.Image bush; // tree_3

  // Skin sprites keyed by skin id -> [alive, stunned].
  final Map<String, ui.Image> _skinAlive = {};
  final Map<String, ui.Image> _skinStunned = {};

  Future<void> loadAll() async {
    if (loaded) {
      return;
    }

    title = await _load('assets/title.webp');
    logo = await _load('assets/assets/logo.webp');

    cartAmber = await _load('assets/assets/cart_1.webp');
    cartAzure = await _load('assets/assets/cart_2.webp');
    cartGold = await _load('assets/assets/cart_3.webp');

    tileFloor = await _load('assets/assets/bg_island.webp');
    tileRail = await _load('assets/assets/bg_rail.webp');
    bgStart = await _load('assets/assets/bg_start.webp');
    bgIslands = await _load('assets/assets/bg_islands.webp');
    bgRailAlt = await _load('assets/assets/bg_rail_alt.webp');

    torch = await _load('assets/assets/torch_1.webp');
    torchAlt = await _load('assets/assets/torch_2.webp');
    tree1 = await _load('assets/assets/tree_1.webp');
    tree2 = await _load('assets/assets/tree_2.webp');
    bush = await _load('assets/assets/tree_3.webp');

    for (final skin in kSkins) {
      _skinAlive[skin.id] = await _load(skin.aliveAsset);
      _skinStunned[skin.id] = await _load(skin.stunnedAsset);
    }

    loaded = true;
  }

  ui.Image cartImage(CartColor color) {
    switch (color) {
      case CartColor.amber:
        return cartAmber;
      case CartColor.azure:
        return cartAzure;
      case CartColor.gold:
        return cartGold;
    }
  }

  ui.Image minerAlive(String skinId) => _skinAlive[skinId] ?? _skinAlive['classic']!;

  ui.Image minerStunned(String skinId) =>
      _skinStunned[skinId] ?? _skinStunned['classic']!;

  Future<ui.Image> _load(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
