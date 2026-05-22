import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../app.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    required this.runBootstrap,
    required this.onComplete,
  });

  final Future<PlayerProgress> Function(ValueChanged<int> onStageChanged)
      runBootstrap;
  final Future<void> Function(PlayerProgress progress) onComplete;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const List<String> _barByStage = [
    'assets/loading/bar_0.webp',
    'assets/loading/bar_1.webp',
    'assets/loading/bar_2.webp',
    'assets/loading/bar_3.webp',
  ];

  VideoPlayerController? _videoController;
  Orientation? _activeOrientation;
  int _stage = 0;
  String? _errorText;
  int _videoLoadToken = 0;
  bool _videoSwitchInProgress = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startBoot();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _startBoot() async {
    try {
      final progress = await widget.runBootstrap((stage) {
        if (!mounted) {
          return;
        }
        final nextStage = stage.clamp(0, _barByStage.length - 1);
        if (nextStage <= _stage) {
          return;
        }
        setState(() {
          _stage = nextStage;
        });
      });

      if (!mounted) {
        return;
      }
      await widget.onComplete(progress);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
      });
    }
  }

  Future<void> _updateOrientationVideo(Orientation orientation) async {
    if (_activeOrientation == orientation || _videoSwitchInProgress) {
      return;
    }

    _videoSwitchInProgress = true;
    _activeOrientation = orientation;
    final token = ++_videoLoadToken;
    final String path = orientation == Orientation.landscape
        ? 'assets/loading/splash_landscape.mp4'
        : 'assets/loading/splash_portrait.mp4';

    final old = _videoController;
    final controller = VideoPlayerController.asset(path);
    _videoController = controller;

    try {
      await old?.dispose();
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted ||
          _videoController != controller ||
          token != _videoLoadToken) {
        await controller.dispose();
        return;
      }
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      await controller.dispose();
      if (mounted && token == _videoLoadToken) {
        setState(() {
          _errorText = 'Failed to load video';
        });
      }
    } finally {
      _videoSwitchInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: OrientationBuilder(
        builder: (context, orientation) {
          _updateOrientationVideo(orientation);

          final video = _videoController;
          final hasVideo = video != null && video.value.isInitialized;
          final progressAsset = _barByStage[_stage];

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
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.985, end: 1.0)
                                  .animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Image.asset(
                          progressAsset,
                          key: ValueKey(progressAsset),
                          width: 280,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _errorText == null
                            ? 'Preparing dungeon...'
                            : 'Loading failed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
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
