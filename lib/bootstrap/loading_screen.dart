import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    required this.runBootstrap,
    required this.onComplete,
  });

  final Future<void> Function(ValueChanged<int> onStageChanged) runBootstrap;
  final Future<void> Function() onComplete;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  // 0..3 bootstrap stages → mapped to 0..1 progress
  static const int _totalStages = 3;
  int _stage = 0;
  String? _errorText;

  late final AnimationController _dotController;
  late final AnimationController _barController;

  /// Smooth animated progress value (0.0 → 1.0).
  double _barProgress = 0.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Animated "..." dots cycling 0-1-2-3
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    // Smooth bar fill controller — drives the visual bar independently from
    // discrete stage ticks so it glides smoothly rather than jumping.
    _barController = AnimationController(vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _barProgress = _barController.value);
      });

    _startBoot();
  }

  @override
  void dispose() {
    _dotController.dispose();
    _barController.dispose();
    super.dispose();
  }

  Future<void> _startBoot() async {
    try {
      await widget.runBootstrap((stage) {
        if (!mounted) return;
        final next = stage.clamp(0, _totalStages);
        if (next <= _stage) return;
        setState(() => _stage = next);
        final target = next / _totalStages;
        _barController.animateTo(
          target,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
        );
      });

      // Fill bar to 100% before navigating.
      await _barController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

      if (!mounted) return;
      await widget.onComplete();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.size.width > mq.size.height;
    final bgAsset = landscape
        ? 'assets/loading/splash_landscape.png'
        : 'assets/loading/splash_portrait.png';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Splash background ───────────────────────────────────────
          Image.asset(bgAsset, fit: BoxFit.cover),

          // ── Bottom vignette so bar / text read well ─────────────────
          const _BottomFade(),

          // ── Loading bar + text ──────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  landscape ? 40 : 28,
                  0,
                  landscape ? 40 : 28,
                  landscape ? 18 : 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LoadingBar(progress: _barProgress, landscape: landscape),
                    const SizedBox(height: 10),
                    _errorText == null
                        ? _AnimatedLoadingText(controller: _dotController)
                        : Text(
                            'Loading failed',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom vignette ─────────────────────────────────────────────────────────

class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.45, 0.75, 1.0],
          colors: [
            Colors.transparent,
            Color(0xAA000000),
            Color(0xDD000000),
          ],
        ),
      ),
    );
  }
}

// ── Animated "Loading..." dots ───────────────────────────────────────────────

class _AnimatedLoadingText extends StatelessWidget {
  const _AnimatedLoadingText({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
        builder: (context, child) {
        final dots = '.' * (1 + (controller.value * 3).floor() % 3);
        return Text(
          'Loading$dots',
          style: const TextStyle(
            color: Color(0xFFFFE082),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
          ),
        );
      },
    );
  }
}

// ── Loading bar ──────────────────────────────────────────────────────────────

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.progress, required this.landscape});

  final double progress;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final barW = landscape
        ? (mq.size.width * 0.55).clamp(240.0, 500.0)
        : (mq.size.width - 56).clamp(200.0, 420.0);

    return SizedBox(
      width: barW,
      height: 22,
      child: CustomPaint(
        painter: _BarPainter(progress: progress),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // Track
    canvas.drawRRect(
      rrect,
      Paint()..color = const Color(0xFF1A1200),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8B6914),
    );

    // Fill
    final fillW = (size.width * progress).clamp(0.0, size.width);
    if (fillW > 0) {
      final fillRect = Rect.fromLTWH(0, 0, fillW, size.height);
      final fillRRect = RRect.fromRectAndRadius(fillRect, Radius.circular(r));

      canvas.save();
      canvas.clipRRect(rrect);

      // Gradient fill
      canvas.drawRRect(
        fillRRect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFD740), Color(0xFFFF8F00)],
          ).createShader(fillRect),
      );

      // Gloss shine
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fillW, size.height * 0.45),
          Radius.circular(r),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );

      // Animated sparkle at leading edge
      if (progress > 0.02 && progress < 0.99) {
        final sparkX = fillW - 4;
        canvas.drawRect(
          Rect.fromLTWH(sparkX, 0, 4, size.height),
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(Rect.fromLTWH(sparkX, 0, 4, size.height)),
        );
      }

      canvas.restore();
    }

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1.5;
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(
        Offset(x, size.height * 0.2),
        Offset(x, size.height * 0.8),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.progress != progress;
}
