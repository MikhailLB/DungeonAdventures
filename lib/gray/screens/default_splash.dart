import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// Built-in splash for the gray boot phase.
// Reuses DungeonAdventures loading assets (video + bar images).

class DefaultGraySplash extends StatefulWidget {
  final Future<void> Function(ValueChanged<int> onStage) runBoot;
  final Future<void> Function() onComplete;

  const DefaultGraySplash({
    super.key,
    required this.runBoot,
    required this.onComplete,
  });

  @override
  State<DefaultGraySplash> createState() => _DefaultGraySplashState();
}

class _DefaultGraySplashState extends State<DefaultGraySplash> {
  static const _bars = [
    'assets/loading/loading_bar_empty.webp',
    'assets/loading/loading_bar_half.webp',
    'assets/loading/loading_bar_almost.webp',
    'assets/loading/loading_bar_full.webp',
  ];

  VideoPlayerController? _vid;
  Orientation? _activeOrientation;
  int _barStage = 0;
  bool _switching = false;
  int _vidToken = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startBoot();
  }

  @override
  void dispose() {
    _vid?.dispose();
    super.dispose();
  }

  Future<void> _startBoot() async {
    try {
      await widget.runBoot((stage) {
        if (!mounted) return;
        final next = stage.clamp(0, _bars.length - 1);
        if (next > _barStage) setState(() => _barStage = next);
      });
      if (mounted) await widget.onComplete();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _ensureVideo(Orientation orientation) async {
    if (_activeOrientation == orientation || _switching) return;
    _switching = true;
    _activeOrientation = orientation;
    final token = ++_vidToken;
    final path = orientation == Orientation.landscape
        ? 'assets/loading/16x9_loading_screen.mp4'
        : 'assets/loading/9x16_loading_screen.mp4';

    final old = _vid;
    final ctrl = VideoPlayerController.asset(path);
    _vid = ctrl;

    try {
      await old?.dispose();
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0);
      await ctrl.play();
      if (!mounted || _vid != ctrl || token != _vidToken) {
        await ctrl.dispose();
        return;
      }
      if (mounted) setState(() {});
    } catch (_) {
      await ctrl.dispose();
    } finally {
      _switching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: OrientationBuilder(
        builder: (ctx, orientation) {
          _ensureVideo(orientation);

          final video = _vid;
          final hasVideo = video != null && video.value.isInitialized;
          final barAsset = _bars[_barStage];

          return Stack(
            fit: StackFit.expand,
            children: [
              if (hasVideo)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: video.value.size.width,
                    height: video.value.size.height,
                    child: VideoPlayer(video),
                  ),
                )
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF111522), Color(0xFF05070D)],
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOut,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.985, end: 1.0)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: Image.asset(
                          barAsset,
                          key: ValueKey(barAsset),
                          width: 280,
                          fit: BoxFit.contain,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Loading error',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
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
}
