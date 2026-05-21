import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app.dart';
import 'game_assets.dart';
import 'game_engine.dart';
import 'game_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.assets,
    required this.initialProgress,
  });

  final GameAssets assets;
  final PlayerProgress initialProgress;

  static const String highScoreKey = 'dungeon_high_score';
  static const String bestDistanceKey = 'dungeon_best_distance';
  static const String totalCoinsKey = 'dungeon_total_coins';

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final GameEngine _engine = GameEngine();
  late final Ticker _ticker;
  late final AnimationController _shopController;
  Duration _lastTick = Duration.zero;

  int _walletCoins = 0;
  bool _roundRewardCommitted = false;
  Offset? _dragStart;
  bool _shopVisible = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _engine.highScore = widget.initialProgress.highScore;
    _engine.bestDistance = widget.initialProgress.bestDistance;
    _walletCoins = widget.initialProgress.totalCoins;
    _shopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shopController.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.016
        : (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    _engine.update(dt.clamp(0.0, 0.05));

    if (_engine.state == GameState.gameOver && !_roundRewardCommitted) {
      _walletCoins += _engine.coinReward;
      _roundRewardCommitted = true;
      _saveProgress();
    }
    if (_engine.state == GameState.playing) {
      _roundRewardCommitted = false;
    }
    setState(() {});
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(GameScreen.highScoreKey, _engine.highScore);
    await prefs.setInt(GameScreen.bestDistanceKey, _engine.bestDistance);
    await prefs.setInt(GameScreen.totalCoinsKey, _walletCoins);
  }

  void _startOrRestartGame() {
    if (_shopVisible) {
      _closeShop();
    }
    _engine.startGame();
    _roundRewardCommitted = false;
  }

  void _returnMenu() {
    _engine.returnToMenu();
    _saveProgress();
  }

  void _handleTap() {
    if (_shopVisible) {
      _closeShop();
    }
  }

  void _openShop() {
    if (_shopVisible) {
      return;
    }
    setState(() => _shopVisible = true);
    _shopController.forward(from: 0);
  }

  Future<void> _closeShop() async {
    if (!_shopVisible) {
      return;
    }
    await _shopController.reverse();
    if (!mounted) {
      return;
    }
    setState(() => _shopVisible = false);
  }

  void _onPanStart(DragStartDetails details) {
    _dragStart = details.localPosition;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStart == null || _engine.state != GameState.playing) {
      return;
    }

    final dx = details.localPosition.dx - _dragStart!.dx;
    final dy = details.localPosition.dy - _dragStart!.dy;
    if (dx.abs() > 26 && dx.abs() > dy.abs()) {
      dx > 0 ? _engine.moveRight() : _engine.moveLeft();
      _dragStart = null;
    } else if (dy.abs() > 26 && dy.abs() > dx.abs()) {
      dy < 0 ? _engine.moveForward() : _engine.moveBackward();
      _dragStart = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A12),
      body: LayoutBuilder(
        builder: (context, constraints) {
          _engine.setSize(constraints.maxWidth, constraints.maxHeight);

          return GestureDetector(
            onTapUp: (_) => _handleTap(),
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: GamePainter(engine: _engine, assets: widget.assets),
                ),
                if (_engine.state == GameState.menu) _buildMenuOverlay(),
                if (_engine.state == GameState.playing) ...[
                  _buildHud(),
                ],
                if (_engine.state == GameState.paused) ...[
                  _buildHud(),
                  _buildPauseOverlay(),
                ],
                if (_engine.state == GameState.gameOver) ...[
                  _buildHud(),
                  _buildGameOverOverlay(),
                ],
                if (_shopVisible ||
                    _shopController.status != AnimationStatus.dismissed)
                  _buildShopOverlay(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuOverlay() {
    final pulse = (sin(_engine.menuTime * 3.2) + 1) / 2;
    final bob = sin(_engine.menuTime * 2.0) * 10;

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.2,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.76),
            Colors.black.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 12),
                const Spacer(),
                _coinChip(_walletCoins),
                const SizedBox(width: 12),
              ],
            ),
            const Spacer(),
            Image.asset(
              'assets/title.webp',
              width: 330,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 22),
            Transform.translate(
              offset: Offset(0, bob),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.25 + pulse * 0.2),
                      blurRadius: 24 + pulse * 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/assets/player.webp',
                  width: 130,
                  height: 130,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _primaryButton(
              icon: Icons.play_arrow_rounded,
              label: 'START RUN',
              colors: const [Color(0xFF66BB6A), Color(0xFF2E7D32)],
              onTap: _startOrRestartGame,
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              icon: Icons.storefront_rounded,
              label: 'SHOP',
              onTap: _openShop,
            ),
            const SizedBox(height: 16),
            _statsBadge(),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _Hint(icon: Icons.swipe, text: 'Swipe controls only'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://dungeonadventtures.com/privacy-policy.html'),
                    mode: LaunchMode.inAppWebView,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: Color(0xFF7B8AAB),
                      fontSize: 11,
                    ),
                  ),
                ),
                const Text('·', style: TextStyle(color: Color(0xFF4A5568), fontSize: 11)),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://dungeonadventtures.com/support.html'),
                    mode: LaunchMode.inAppWebView,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Support',
                    style: TextStyle(
                      color: Color(0xFF7B8AAB),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildShopOverlay() {
    final opacity = CurvedAnimation(
      parent: _shopController,
      curve: Curves.easeOut,
    );
    final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _shopController, curve: Curves.easeOutBack),
    );

    return Positioned.fill(
      child: FadeTransition(
        opacity: opacity,
        child: Material(
          color: Colors.black.withValues(alpha: 0.7),
          child: GestureDetector(
            onTap: () {
              _closeShop();
            },
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: ScaleTransition(
                  scale: scale,
                  child: Container(
                    width: 380,
                    constraints: const BoxConstraints(maxWidth: 380, maxHeight: 560),
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121722),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.storefront_rounded, color: Color(0xFFFFD54F)),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'SHOP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _closeShop();
                              },
                              child: const Icon(Icons.close, color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Skins are coming soon. Animation and placeholders are ready.',
                          style: TextStyle(color: Colors.white70, fontSize: 12.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: GridView.builder(
                            itemCount: 6,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1.05,
                            ),
                            itemBuilder: (context, index) {
                              final pulse = (sin(_engine.menuTime * 3 + index) + 1) / 2;
                              return Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF07090E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFFD54F)
                                        .withValues(alpha: 0.2 + pulse * 0.2),
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    const Positioned.fill(
                                      child: Center(
                                        child: Icon(
                                          Icons.question_mark_rounded,
                                          size: 72,
                                          color: Color(0xFF2F3747),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 8,
                                      right: 8,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.lock, color: Color(0xFFFFD54F), size: 13),
                                            SizedBox(width: 4),
                                            Text(
                                              'COMING SOON',
                                              style: TextStyle(
                                                color: Color(0xFFFFE082),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 10.5,
                                                letterSpacing: 0.6,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHud() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pill(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 17),
                      const SizedBox(width: 4),
                      Text(
                        '${_engine.score}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _pill(
                  Text(
                    '${_engine.distance}m',
                    style: const TextStyle(
                      color: Color(0xFF8BE38F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _coinChip(_walletCoins, plus: _engine.state == GameState.playing ? _engine.collectedCoins : null),
                const SizedBox(height: 4),
                _pill(
                  Text(
                    '${_engine.multiplier.toStringAsFixed(2)}x',
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                if (_engine.state == GameState.playing)
                  GestureDetector(
                    onTap: _engine.togglePause,
                    child: _pill(const Icon(Icons.pause, color: Colors.white, size: 18)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_outline, color: Colors.white, size: 84),
            const SizedBox(height: 12),
            const Text(
              'PAUSED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),
            _primaryButton(
              icon: Icons.play_arrow_rounded,
              label: 'RESUME',
              colors: const [Color(0xFF66BB6A), Color(0xFF2E7D32)],
              onTap: _engine.togglePause,
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              icon: Icons.replay,
              label: 'RESTART',
              onTap: _startOrRestartGame,
            ),
            const SizedBox(height: 10),
            _secondaryButton(
              icon: Icons.home,
              label: 'MENU',
              onTap: _returnMenu,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    final visible = _engine.deathTimer > 0.8;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      child: IgnorePointer(
        ignoring: !visible,
        child: Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/assets/player_dead.webp', width: 120, height: 120),
                  const SizedBox(height: 6),
                  const Text(
                    'RUN OVER',
                    style: TextStyle(
                      color: Color(0xFFFF5252),
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      _resultCard('Score', '${_engine.score}', Icons.star, Colors.amber),
                      _resultCard('Distance', '${_engine.distance}m', Icons.straighten, const Color(0xFF8BE38F)),
                      _resultCard('Coins', '${_engine.collectedCoins}', Icons.monetization_on, const Color(0xFFFFD54F)),
                      _resultCard('Reward', '+${_engine.coinReward}', Icons.auto_awesome, const Color(0xFFFFB74D)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_engine.score >= _engine.highScore && _engine.score > 0)
                    _recordBadge('New high score!'),
                  if (_engine.distance >= _engine.bestDistance && _engine.distance > 0)
                    _recordBadge('New distance record!'),
                  const SizedBox(height: 14),
                  _primaryButton(
                    icon: Icons.replay,
                    label: 'RESTART',
                    colors: const [Color(0xFF66BB6A), Color(0xFF2E7D32)],
                    onTap: _startOrRestartGame,
                  ),
                  const SizedBox(height: 10),
                  _secondaryButton(
                    icon: Icons.home,
                    label: 'MENU',
                    onTap: _returnMenu,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.amber, size: 17),
          const SizedBox(width: 4),
          Text(
            'Best ${_engine.highScore}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.straighten, color: Color(0xFF8BE38F), size: 17),
          const SizedBox(width: 4),
          Text(
            '${_engine.bestDistance}m',
            style: const TextStyle(color: Color(0xFF8BE38F), fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _coinChip(int coins, {int? plus}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(
            '$coins',
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700),
          ),
          if (plus != null) ...[
            const SizedBox(width: 5),
            Text(
              '+$plus',
              style: const TextStyle(color: Color(0xFFFFE082), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: child,
    );
  }

  Widget _resultCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _recordBadge(String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC107), Color(0xFFFF9800)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _primaryButton({
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white60, size: 15),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
