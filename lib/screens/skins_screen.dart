import 'package:flutter/material.dart';

import '../cartlock/progress_store.dart';
import '../cartlock/skins.dart';
import 'ui_kit.dart';

class SkinsScreen extends StatefulWidget {
  const SkinsScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<SkinsScreen> createState() => _SkinsScreenState();
}

class _SkinsScreenState extends State<SkinsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Dungeon.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Unlock new keepers by completing dungeons. Free - no purchases.',
                  style: TextStyle(color: Dungeon.textDim, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: kSkins.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final skin = kSkins[index];
                  final unlocked = widget.store.isSkinUnlocked(skin);
                  final selected = widget.store.selectedSkinId == skin.id;
                  return _SkinCard(
                    skin: skin,
                    unlocked: unlocked,
                    selected: selected,
                    onTap: () async {
                      if (!unlocked) return;
                      await widget.store.selectSkin(skin.id);
                      setState(() {});
                    },
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
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const Text(
            'KEEPERS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          StatChip(
            icon: Icons.flag_rounded,
            label: '${widget.store.completedCount}',
            color: Dungeon.green,
          ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  final MinerSkin skin;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C2014), Color(0xFF17100A)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Dungeon.gold
                : (unlocked ? Dungeon.stroke : Colors.black54),
            width: selected ? 2.2 : 1.2,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ColorFiltered(
                    colorFilter: unlocked
                        ? const ColorFilter.mode(
                            Colors.transparent, BlendMode.multiply)
                        : const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0, 0, 0, 1, 0,
                          ]),
                    child: Image.asset(skin.aliveAsset, fit: BoxFit.contain),
                  ),
                  if (!unlocked)
                    const Icon(Icons.lock_rounded,
                        color: Colors.white70, size: 34),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              skin.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            if (selected)
              const _Tag(text: 'EQUIPPED', color: Dungeon.gold)
            else if (unlocked)
              const _Tag(text: 'TAP TO EQUIP', color: Dungeon.green)
            else
              _Tag(
                text: 'CLEAR ${skin.unlockLevels} LEVELS',
                color: Dungeon.textDim,
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
