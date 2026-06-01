import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'skins.dart';

/// Persists puzzle progress: stars earned per level and the chosen skin.
/// A level is "completed" when it has at least one star.
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs) {
    _load();
  }

  static const String _starsKey = 'cartlock_stars'; // "id:stars,id:stars"
  static const String _skinKey = 'cartlock_skin';
  static const String _tutKey = 'cartlock_tutorial_seen';
  static const String _avatarKey = 'cartlock_avatar_path';

  final SharedPreferences _prefs;

  final Map<int, int> _stars = <int, int>{};
  String _selectedSkinId = 'classic';
  bool _tutorialSeen = false;
  String? _avatarPath;

  static Future<ProgressStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressStore._(prefs);
  }

  void _load() {
    final raw = _prefs.getString(_starsKey) ?? '';
    for (final entry in raw.split(',')) {
      if (entry.isEmpty) {
        continue;
      }
      final parts = entry.split(':');
      if (parts.length == 2) {
        final id = int.tryParse(parts[0]);
        final stars = int.tryParse(parts[1]);
        if (id != null && stars != null) {
          _stars[id] = stars;
        }
      }
    }
    _selectedSkinId = _prefs.getString(_skinKey) ?? 'classic';
    _tutorialSeen = _prefs.getBool(_tutKey) ?? false;
    _avatarPath = _prefs.getString(_avatarKey);
  }

  bool get tutorialSeen => _tutorialSeen;

  /// File path of the player's custom keeper portrait (camera/gallery), if set.
  String? get avatarPath => _avatarPath;

  Future<void> setAvatarPath(String? path) async {
    _avatarPath = path;
    if (path == null || path.isEmpty) {
      await _prefs.remove(_avatarKey);
    } else {
      await _prefs.setString(_avatarKey, path);
    }
    notifyListeners();
  }

  Future<void> markTutorialSeen() async {
    if (_tutorialSeen) {
      return;
    }
    _tutorialSeen = true;
    await _prefs.setBool(_tutKey, true);
  }

  Future<void> _persist() async {
    final encoded =
        _stars.entries.map((e) => '${e.key}:${e.value}').join(',');
    await _prefs.setString(_starsKey, encoded);
    await _prefs.setString(_skinKey, _selectedSkinId);
  }

  int starsFor(int levelId) => _stars[levelId] ?? 0;

  bool isCompleted(int levelId) => starsFor(levelId) > 0;

  int get totalStars => _stars.values.fold(0, (sum, s) => sum + s);

  int get completedCount => _stars.values.where((s) => s > 0).length;

  String get selectedSkinId => _selectedSkinId;

  /// A level is unlocked when it is the first one or the previous is completed.
  bool isLevelUnlocked(int levelId) {
    if (levelId <= 1) {
      return true;
    }
    return isCompleted(levelId - 1);
  }

  bool isSkinUnlocked(MinerSkin skin) => skin.isUnlocked(completedCount);

  /// Records a clear. Keeps the best (highest) star result.
  Future<void> recordResult(int levelId, int stars) async {
    final current = _stars[levelId] ?? 0;
    if (stars > current) {
      _stars[levelId] = stars;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> selectSkin(String skinId) async {
    if (_selectedSkinId == skinId) {
      return;
    }
    _selectedSkinId = skinId;
    await _persist();
    notifyListeners();
  }
}
