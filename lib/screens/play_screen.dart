import 'package:flutter/material.dart';

import '../cartlock/game_assets.dart';
import '../cartlock/levels.dart';
import '../cartlock/models.dart';
import '../cartlock/progress_store.dart';
import '../cartlock/puzzle_engine.dart';
import '../cartlock/puzzle_painter.dart';
import 'ui_kit.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.assets,
    required this.store,
    required this.startLevelId,
  });

  final GameAssets assets;
  final ProgressStore store;
  final int startLevelId;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with TickerProviderStateMixin {
  late LevelDef _level;
  late PuzzleEngine _engine;
  late final AnimationController _step;
  late final AnimationController _ambient;

  Offset? _dragStart;
  bool _movedThisGesture = false;
  bool _showWin = false;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _step = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addStatusListener(_onStepStatus);
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _loadLevel(widget.startLevelId);
    _showTutorial =
        widget.startLevelId == 1 && !widget.store.tutorialSeen;
  }

  @override
  void dispose() {
    _step.dispose();
    _ambient.dispose();
    super.dispose();
  }

  void _loadLevel(int id) {
    _level = kLevels.firstWhere((l) => l.id == id, orElse: () => kLevels.first);
    _engine = PuzzleEngine(_level);
    _showWin = false;
    _step.value = 1.0;
    setState(() {});
  }

  void _onStepStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _engine.solved && !_showWin) {
      _commitWin();
    }
  }

  Future<void> _commitWin() async {
    final stars = _engine.earnedStars;
    await widget.store.recordResult(_level.id, stars);
    if (!mounted) return;
    setState(() => _showWin = true);
  }

  void _tryMove(MoveDir dir) {
    if (_engine.solved || _showWin || _showTutorial) {
      return;
    }
    if (_engine.move(dir)) {
      _step.forward(from: 0);
      setState(() {});
    }
  }

  void _undo() {
    _engine.undo();
    _step.value = 1.0;
    setState(() {});
  }

  void _restart() {
    _engine.reset();
    _step.value = 1.0;
    setState(() => _showWin = false);
  }

  int? get _nextLevelId {
    final idx = kLevels.indexWhere((l) => l.id == _level.id);
    if (idx >= 0 && idx + 1 < kLevels.length) {
      return kLevels[idx + 1].id;
    }
    return null;
  }

  // ---- swipe handling ----
  void _onPanStart(DragStartDetails d) {
    _dragStart = d.localPosition;
    _movedThisGesture = false;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragStart == null || _movedThisGesture) {
      return;
    }
    final dx = d.localPosition.dx - _dragStart!.dx;
    final dy = d.localPosition.dy - _dragStart!.dy;
    const threshold = 22.0;
    if (dx.abs() < threshold && dy.abs() < threshold) {
      return;
    }
    _movedThisGesture = true;
    if (dx.abs() > dy.abs()) {
      _tryMove(dx > 0 ? MoveDir.right : MoveDir.left);
    } else {
      _tryMove(dy > 0 ? MoveDir.down : MoveDir.up);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    _dragStart = null;
    _movedThisGesture = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Dungeon.bg,
      body: Stack(
        children: [
          const _PlayBackdrop(),
          SafeArea(
            child: Column(
              children: [
                _hud(),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_step, _ambient]),
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size.infinite,
                          painter: PuzzlePainter(
                            engine: _engine,
                            assets: widget.assets,
                            skinId: widget.store.selectedSkinId,
                            stepT: Curves.easeInOut.transform(_step.value),
                            time: _ambient.value * 6,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                _controlsHint(),
              ],
            ),
          ),
          if (_showWin) _winOverlay(),
          if (_showTutorial) _tutorialOverlay(),
        ],
      ),
    );
  }

  Widget _tutorialOverlay() {
    const tips = [
      (
        Icons.swipe_rounded,
        'Move the keeper',
        'Swipe up, down, left or right to walk one tile at a time.',
      ),
      (
        Icons.shopping_cart_rounded,
        'Push the carts',
        'Walk into a cart to push it. On rails it slides until it hits a wall, torch or another cart.',
      ),
      (
        Icons.adjust_rounded,
        'Match the colors',
        'Park every cart on the glowing vault of its own color to solve the dungeon.',
      ),
    ];
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        child: Center(
          child: Container(
            width: 330,
            margin: const EdgeInsets.symmetric(horizontal: 22),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: Dungeon.panelDecoration(radius: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'HOW TO PLAY',
                  style: TextStyle(
                    color: Dungeon.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.5,
                  ),
                ),
                const SizedBox(height: 18),
                for (final tip in tips) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Dungeon.azure.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Dungeon.azure.withValues(alpha: 0.4)),
                        ),
                        child: Icon(tip.$1, color: Dungeon.azure, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tip.$2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              tip.$3,
                              style: const TextStyle(
                                color: Dungeon.textDim,
                                fontSize: 12.5,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                StoneButton(
                  label: 'START',
                  icon: Icons.play_arrow_rounded,
                  primary: true,
                  accent: Dungeon.green,
                  onTap: () {
                    widget.store.markTutorialSeen();
                    setState(() => _showTutorial = false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LEVEL ${_level.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                _level.name,
                style: const TextStyle(color: Dungeon.textDim, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          StatChip(
            icon: Icons.directions_walk_rounded,
            label: '${_engine.moveCount}',
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          StatChip(
            icon: Icons.emoji_events_rounded,
            label: '${_level.par}',
          ),
        ],
      ),
    );
  }

  Widget _controlsHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _iconButton(Icons.undo_rounded, 'UNDO',
              _engine.canUndo && !_showWin ? _undo : null),
          const SizedBox(width: 10),
          _iconButton(Icons.refresh_rounded, 'RESTART',
              _showWin ? null : _restart),
          const SizedBox(width: 10),
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.swipe_rounded, color: Dungeon.textDim, size: 16),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Swipe to move',
                    style: TextStyle(color: Dungeon.textDim, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Dungeon.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Dungeon.stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _winOverlay() {
    final stars = widget.store.starsFor(_level.id);
    final next = _nextLevelId;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: Container(
            width: 320,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            decoration: Dungeon.panelDecoration(radius: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SOLVED!',
                  style: TextStyle(
                    color: Dungeon.gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 14),
                StarRow(stars: stars, size: 44),
                const SizedBox(height: 12),
                Text(
                  'Solved in ${_engine.moveCount} moves  •  par ${_level.par}',
                  style: const TextStyle(color: Dungeon.textDim, fontSize: 13),
                ),
                const SizedBox(height: 22),
                if (next != null)
                  StoneButton(
                    label: 'NEXT LEVEL',
                    icon: Icons.skip_next_rounded,
                    primary: true,
                    accent: Dungeon.green,
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => PlayScreen(
                          assets: widget.assets,
                          store: widget.store,
                          startLevelId: next,
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    'You cleared every dungeon!',
                    style: TextStyle(color: Dungeon.green, fontSize: 14),
                  ),
                const SizedBox(height: 10),
                StoneButton(
                  label: 'REPLAY',
                  icon: Icons.refresh_rounded,
                  onTap: _restart,
                ),
                const SizedBox(height: 10),
                StoneButton(
                  label: 'LEVELS',
                  icon: Icons.grid_view_rounded,
                  accent: Dungeon.azure,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayBackdrop extends StatelessWidget {
  const _PlayBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.1,
          colors: [Color(0xFF241A12), Color(0xFF0E0B09)],
        ),
      ),
    );
  }
}
