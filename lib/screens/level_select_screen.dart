import 'package:flutter/material.dart';

import '../cartlock/game_assets.dart';
import '../cartlock/levels.dart';
import '../cartlock/progress_store.dart';
import 'play_screen.dart';
import 'ui_kit.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({
    super.key,
    required this.assets,
    required this.store,
  });

  final GameAssets assets;
  final ProgressStore store;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  Future<void> _open(int levelId) async {
    if (!widget.store.isLevelUnlocked(levelId)) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayScreen(
          assets: widget.assets,
          store: widget.store,
          startLevelId: levelId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Dungeon.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: kLevels.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) {
                  final level = kLevels[index];
                  final unlocked = widget.store.isLevelUnlocked(level.id);
                  final stars = widget.store.starsFor(level.id);
                  return _LevelTile(
                    number: level.id,
                    unlocked: unlocked,
                    stars: stars,
                    onTap: () => _open(level.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const Text(
            'SELECT LEVEL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          StatChip(
            icon: Icons.star_rounded,
            label: '${widget.store.totalStars}',
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.number,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final int number;
  final bool unlocked;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = stars > 0;
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: unlocked
                ? (completed
                    ? const [Color(0xFF3E2E1C), Color(0xFF231811)]
                    : const [Color(0xFF332617), Color(0xFF1B130C)])
                : const [Color(0xFF1A130D), Color(0xFF120C08)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: completed
                ? Dungeon.gold.withValues(alpha: 0.6)
                : unlocked
                    ? Dungeon.stroke
                    : Colors.black.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (unlocked)
              Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              )
            else
              const Icon(Icons.lock_rounded,
                  color: Dungeon.textDim, size: 26),
            const SizedBox(height: 6),
            if (unlocked) StarRow(stars: stars, size: 14),
          ],
        ),
      ),
    );
  }
}
