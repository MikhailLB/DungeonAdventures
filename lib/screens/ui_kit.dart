import 'package:flutter/material.dart';

/// Shared visual language for the dungeon UI: palette, stone buttons, star rows
/// and panel decorations. Keeps every screen consistent and distinct from the
/// old arcade template.
class Dungeon {
  Dungeon._();

  // Warm, torch-lit dungeon palette (bronze + ember on deep brown-black).
  static const Color bg = Color(0xFF0E0B09);
  static const Color panel = Color(0xFF241A12);
  static const Color panelHi = Color(0xFF34261A);
  static const Color stroke = Color(0xFF53402A);
  static const Color gold = Color(0xFFEEB454);
  static const Color amber = Color(0xFFFF7A45);
  static const Color azure = Color(0xFF3FC6DE);
  static const Color green = Color(0xFF8AC559);
  static const Color textDim = Color(0xFFA68C70);

  static BoxDecoration panelDecoration({double radius = 18}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1F15), Color(0xFF160F0A)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: stroke.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      );
}

class StoneButton extends StatefulWidget {
  const StoneButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = Dungeon.gold,
    this.primary = false,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final bool primary;
  final bool enabled;

  @override
  State<StoneButton> createState() => _StoneButtonState();
}

class _StoneButtonState extends State<StoneButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _down = false);
              widget.onTap();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.45,
          child: Container(
            width: 260,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            decoration: BoxDecoration(
              gradient: widget.primary
                  ? LinearGradient(colors: [
                      accent,
                      Color.lerp(accent, Colors.black, 0.35)!,
                    ])
                  : const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3C2D1E), Color(0xFF1E150E)],
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.primary
                    ? Colors.white.withValues(alpha: 0.4)
                    : accent.withValues(alpha: 0.45),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.primary ? accent : Colors.black)
                      .withValues(alpha: widget.primary ? 0.45 : 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: widget.primary ? Colors.white : accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.primary ? Colors.white : Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide carved-stone menu button: a glowing icon medallion on the left, a
/// title (and optional subtitle) in the middle, and a chevron on the right.
class PlateButton extends StatefulWidget {
  const PlateButton({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent = Dungeon.gold,
    this.featured = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color accent;
  final bool featured;

  @override
  State<PlateButton> createState() => _PlateButtonState();
}

class _PlateButtonState extends State<PlateButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.featured
                  ? [
                      Color.lerp(accent, Colors.white, 0.12)!,
                      Color.lerp(accent, Colors.black, 0.42)!,
                    ]
                  : const [Color(0xFF3C2D1E), Color(0xFF1E150E)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: widget.featured
                  ? Colors.white.withValues(alpha: 0.45)
                  : accent.withValues(alpha: 0.4),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.featured ? accent : Colors.black)
                    .withValues(alpha: widget.featured ? 0.5 : 0.4),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color.lerp(accent, Colors.white, 0.3)!,
                      Color.lerp(accent, Colors.black, 0.3)!,
                    ],
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.7),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 18, this.max = 3});

  final int stars;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: filled ? Dungeon.gold : Dungeon.textDim.withValues(alpha: 0.5),
          ),
        );
      }),
    );
  }
}

class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = Dungeon.gold,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
