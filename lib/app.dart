import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bootstrap/loading_screen.dart';
import 'game/game_assets.dart';
import 'game/game_screen.dart';

class PlayerProgress {
  final int highScore;
  final int bestDistance;
  final int totalCoins;

  const PlayerProgress({
    required this.highScore,
    required this.bestDistance,
    required this.totalCoins,
  });
}

/// White fallback: game loading screen → GameScreen.
/// Used as [fallbackHomeBuilder] by [GrayBoot.buildHome()].
class DungeonBootstrap extends StatefulWidget {
  const DungeonBootstrap({super.key});

  @override
  State<DungeonBootstrap> createState() => _DungeonBootstrapState();
}

class _DungeonBootstrapState extends State<DungeonBootstrap> {
  final GameAssets _assets = GameAssets();
  PlayerProgress? _progress;

  Future<PlayerProgress> _bootstrap(ValueChanged<int> onStageChanged) async {
    onStageChanged(0);

    // Drive the loading bar from real per-image progress rather than fixed delays.
    // stage 1 → first image decoded, stage 2 → halfway through images.
    await _assets.loadAll(onProgress: (done, total) {
      if (done == 1) onStageChanged(1);
      if (done == total ~/ 2) onStageChanged(2);
    });

    final prefs = await SharedPreferences.getInstance();
    final progress = PlayerProgress(
      highScore: prefs.getInt(GameScreen.highScoreKey) ?? 0,
      bestDistance: prefs.getInt(GameScreen.bestDistanceKey) ?? 0,
      totalCoins: prefs.getInt(GameScreen.totalCoinsKey) ?? 0,
    );

    onStageChanged(3);
    // Brief pause so the "full" bar is visible before transition.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return progress;
  }

  Future<void> _onLoadingComplete(PlayerProgress progress) async {
    await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
    if (!mounted) return;
    setState(() => _progress = progress);
  }

  @override
  Widget build(BuildContext context) {
    if (_progress == null) {
      return LoadingScreen(
        runBootstrap: _bootstrap,
        onComplete: _onLoadingComplete,
      );
    }
    return GameScreen(
      assets: _assets,
      initialProgress: _progress!,
    );
  }
}
