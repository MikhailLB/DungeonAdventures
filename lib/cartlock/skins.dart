/// Player skins. All four turkey skins ship in the bundle and are unlocked by
/// progress (number of completed levels) - no purchases involved.
class MinerSkin {
  const MinerSkin({
    required this.id,
    required this.name,
    required this.aliveAsset,
    required this.stunnedAsset,
    required this.unlockLevels,
  });

  final String id;
  final String name;
  final String aliveAsset;
  final String stunnedAsset;

  /// Number of levels that must be completed before this skin unlocks.
  final int unlockLevels;

  bool isUnlocked(int completedLevels) => completedLevels >= unlockLevels;
}

const List<MinerSkin> kSkins = [
  MinerSkin(
    id: 'classic',
    name: 'Keeper',
    aliveAsset: 'assets/assets/player.webp',
    stunnedAsset: 'assets/assets/player_dead.webp',
    unlockLevels: 0,
  ),
  MinerSkin(
    id: 'cowboy',
    name: 'Sheriff',
    aliveAsset: 'assets/assets/turkey_cowboy_asset.webp',
    stunnedAsset: 'assets/assets/turkey_cowboy_death_asset.webp',
    unlockLevels: 6,
  ),
  MinerSkin(
    id: 'fire',
    name: 'Ember',
    aliveAsset: 'assets/assets/turkey_fire_asset.webp',
    stunnedAsset: 'assets/assets/turkey_fire_death_asset.webp',
    unlockLevels: 18,
  ),
  MinerSkin(
    id: 'ghost',
    name: 'Wraith',
    aliveAsset: 'assets/assets/turkey_ghost_asset.webp',
    stunnedAsset: 'assets/assets/turkey_ghost_death_asset.webp',
    unlockLevels: 32,
  ),
];

MinerSkin skinById(String id) =>
    kSkins.firstWhere((s) => s.id == id, orElse: () => kSkins.first);
