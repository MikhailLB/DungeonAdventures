import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cartlock/game_assets.dart';
import '../cartlock/levels.dart';
import '../cartlock/progress_store.dart';
import '../cartlock/skins.dart';
import 'avatar_badge.dart';
import 'level_select_screen.dart';
import 'play_screen.dart';
import 'skins_screen.dart';
import 'ui_kit.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.assets, required this.store});

  final GameAssets assets;
  final ProgressStore store;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  int get _nextLevelId {
    for (final level in kLevels) {
      if (!widget.store.isCompleted(level.id) &&
          widget.store.isLevelUnlocked(level.id)) {
        return level.id;
      }
    }
    return kLevels.last.id;
  }

  Future<void> _play() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayScreen(
          assets: widget.assets,
          store: widget.store,
          startLevelId: _nextLevelId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _levels() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LevelSelectScreen(
          assets: widget.assets,
          store: widget.store,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _skins() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SkinsScreen(store: widget.store),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final skin = skinById(widget.store.selectedSkinId);
    final started = widget.store.completedCount > 0;

    return Scaffold(
      backgroundColor: Dungeon.bg,
      body: AnimatedBuilder(
        animation: _ambient,
        builder: (context, _) {
          final t = _ambient.value;
          final bob = sin(t * 2 * pi) * 7;
          final drift = sin(t * 2 * pi) * 10;

          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.scale(
                scale: 1.18,
                child: Transform.translate(
                  offset: Offset(drift, 6),
                  child: Image.asset(
                    'assets/assets/bg_start.webp',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [Color(0x55000000), Color(0xF20E0B09)],
                  ),
                ),
              ),
              _torchGlow(const Alignment(-0.86, -0.78), t, 0),
              _torchGlow(const Alignment(0.86, -0.78), t, 1.4),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          AvatarBadge(store: widget.store),
                          const SizedBox(width: 10),
                          StatChip(
                            icon: Icons.star_rounded,
                            label:
                                '${widget.store.totalStars}/${kLevels.length * 3}',
                          ),
                          const Spacer(),
                          StatChip(
                            icon: Icons.flag_rounded,
                            label:
                                '${widget.store.completedCount}/${kLevels.length}',
                            color: Dungeon.green,
                          ),
                        ],
                      ),
                      const Spacer(flex: 2),
                      Image.asset('assets/title.webp', width: 290),
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Dungeon.gold.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'C A R T   L O C K',
                          style: TextStyle(
                            color: Dungeon.gold,
                            fontSize: 13,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Transform.translate(
                        offset: Offset(0, bob),
                        child: _hero(skin),
                      ),
                      const Spacer(),
                      PlateButton(
                        title: started ? 'CONTINUE' : 'PLAY',
                        subtitle: 'Level $_nextLevelId',
                        icon: Icons.play_arrow_rounded,
                        featured: true,
                        accent: Dungeon.green,
                        onTap: _play,
                      ),
                      const SizedBox(height: 11),
                      PlateButton(
                        title: 'LEVELS',
                        subtitle: '${widget.store.completedCount} cleared',
                        icon: Icons.grid_view_rounded,
                        onTap: _levels,
                      ),
                      const SizedBox(height: 11),
                      PlateButton(
                        title: 'KEEPERS',
                        subtitle: skin.name,
                        icon: Icons.auto_awesome_rounded,
                        accent: Dungeon.azure,
                        onTap: _skins,
                      ),
                      const Spacer(flex: 2),
                      _footer(),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero(MinerSkin skin) {
    return SizedBox(
      height: 168,
      width: 280,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // stone ledge
          Container(
            width: 250,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3C2D1E), Color(0xFF1E150E)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Dungeon.stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: Image.asset('assets/assets/cart_1.webp', width: 92),
          ),
          Positioned(
            left: 28,
            bottom: 20,
            child: Image.asset(skin.aliveAsset, width: 122),
          ),
        ],
      ),
    );
  }

  Widget _torchGlow(Alignment align, double t, double phase) {
    final flicker = 0.6 + 0.4 * sin(t * 2 * pi * 3 + phase);
    return Align(
      alignment: align,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB74D).withValues(alpha: 0.28 * flicker),
              blurRadius: 28,
              spreadRadius: 6,
            ),
          ],
        ),
        child: Image.asset('assets/assets/torch_1.webp', fit: BoxFit.contain),
      ),
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _link('Privacy Policy',
            'https://dungeonadventtures.com/privacy-policy.html'),
        const Text('  ·  ',
            style: TextStyle(color: Dungeon.textDim, fontSize: 12)),
        _link('Support', 'https://dungeonadventtures.com/support.html'),
      ],
    );
  }

  Widget _link(String label, String url) {
    return TextButton(
      onPressed: () => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.inAppWebView,
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(color: Dungeon.textDim, fontSize: 12),
      ),
    );
  }
}
