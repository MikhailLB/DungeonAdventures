import 'dart:ui' as ui;
import 'package:flutter/services.dart';

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

  Future<void> loadAll() async {
    if (loaded) {
      return;
    }

    final results = await Future.wait<ui.Image>([
      _load('assets/game_name.webp'), // 0
      _load('assets/assets/logo.webp'), // 1
      _load('assets/assets/turkey_asset.webp'), // 2
      _load('assets/assets/turkey_death_asset.webp'), // 3
      _load('assets/assets/turkey_fired_asset.webp'), // 4
      _load('assets/assets/trolley_1_asset.webp'), // 5
      _load('assets/assets/trolley_2_asset.webp'), // 6
      _load('assets/assets/trolley_3_asset.webp'), // 7
      _load('assets/assets/bg_start_asset.webp'), // 8
      _load('assets/assets/bg_ostrovok_asset.webp'), // 9
      _load('assets/assets/bg_s_ostrovkam_asset.webp'), // 10
      _load('assets/assets/bg_relsa_asset.webp'), // 11
      _load('assets/assets/bg_s_relsami-elementor-io-optimized.webp'), // 12
      _load('assets/assets/bg_relsa-elementor-io-optimized.webp'), // 13
      _load('assets/assets/bg_relsa_ostrovok_asset.webp'), // 14
      _load('assets/assets/tree_asset.webp'), // 15
      _load('assets/assets/tree_asset_2.webp'), // 16
      _load('assets/assets/tree_asset_3.webp'), // 17
      _load('assets/assets/torch_asset.webp'), // 18
      _load('assets/assets/torch_asset-elementor-io-optimized.webp'), // 19
    ]);

    gameName = results[0];
    logo = results[1];
    turkeyAlive = results[2];
    turkeyDead = results[3];
    turkeyFired = results[4];
    trolley1 = results[5];
    trolley2 = results[6];
    trolley3 = results[7];
    bgStart = results[8];
    bgSafe = results[9];
    bgSafeAlt = results[10];
    bgRail = results[11];
    bgRailAlt = results[12];
    bgRailMix = results[13];
    bgRailIsland = results[14];
    tree = results[15];
    tree2 = results[16];
    tree3 = results[17];
    torch = results[18];
    torchAlt = results[19];
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

  Future<ui.Image> _load(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
