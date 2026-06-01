import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../infra/cold_tap_reader.dart';
import '../infra/dungeon_vault.dart';
import '../infra/hub_dispatch.dart';
import '../infra/install_tracker.dart';
import '../infra/net_probe.dart';
import '../infra/signal_relay.dart';
import '../models/route_mode.dart';
import 'offline_screen.dart';
import 'signal_screen.dart';
import 'vault_browser.dart';

enum _LoadStep { empty, midway, done }

/// ★ Core dungeon hub splash. Shows the loading video while running the
/// attribution pipeline, then routes to WebView (gray) or the game (white).
class VaultSplash extends StatefulWidget {
  final DungeonVault vault;
  final NetProbe probe;
  final InstallTracker tracker;
  final HubDispatch dispatch;
  final SignalRelay relay;

  /// Callback invoked when the hub decides the user is organic and should see
  /// the white-part game. Replace with your actual game navigation.
  final VoidCallback onLaunchGame;

  const VaultSplash({
    super.key,
    required this.vault,
    required this.probe,
    required this.tracker,
    required this.dispatch,
    required this.relay,
    required this.onLaunchGame,
  });

  @override
  State<VaultSplash> createState() => _VaultSplashState();
}

class _VaultSplashState extends State<VaultSplash> {
  VideoPlayerController? _vid;
  bool _videoReady = false;
  _LoadStep _loadStep = _LoadStep.empty;
  bool _routed = false;
  Orientation? _lastOrientation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _launch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final o = MediaQuery.of(context).orientation;
    if (o != _lastOrientation) {
      _lastOrientation = o;
      _swapVideo(o);
    }
  }

  Future<void> _swapVideo(Orientation o) async {
    final asset = o == Orientation.landscape
        ? 'assets/loading/splash_landscape.mp4'
        : 'assets/loading/splash_portrait.mp4';
    final old = _vid;
    final ctrl = VideoPlayerController.asset(asset);
    try {
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(0);
      ctrl.play();
      if (!mounted) { ctrl.dispose(); return; }
      setState(() { _vid = ctrl; _videoReady = true; });
      old?.dispose();
    } catch (_) {
      ctrl.dispose();
    }
  }

  void _setStep(_LoadStep s) {
    if (mounted) setState(() => _loadStep = s);
  }

  Future<void> _launch() async {
    widget.relay.onTokenRefresh = _onTokenRefresh;

    // HIGHEST PRIORITY: read cold-start push URL from SceneDelegate.
    // Must happen BEFORE any other async work to avoid race conditions.
    final nativeColdUrl = await ColdTapReader.consumeTapUrl();
    if (nativeColdUrl != null && nativeColdUrl.isNotEmpty) {
      debugPrint('[DGA.VS] native cold-start url → $nativeColdUrl');
      await widget.vault.writeMode(RouteMode.web);
      await widget.vault.consumeOneShotUrl();
      unawaited(_backgroundDispatch());
      _openContent(nativeColdUrl);
      return;
    }

    _setStep(_LoadStep.empty);
    final mode = widget.vault.readMode();

    switch (mode) {
      case RouteMode.web:
        _setStep(_LoadStep.midway);
        final pushFuture = widget.relay.bootstrap().catchError((_) {});
        await _runWebMode(pushFuture: pushFuture);
        break;
      case RouteMode.game:
        _setStep(_LoadStep.midway);
        unawaited(widget.relay.bootstrap().catchError((_) {}));
        final recovered = await _tryRestoreWebMode();
        if (recovered) return;
        _setStep(_LoadStep.done);
        await Future.delayed(const Duration(milliseconds: 600));
        _openGame();
        break;
      case RouteMode.fresh:
        await widget.relay.bootstrap().catchError((_) {});
        await _runFreshMode();
        break;
    }
  }

  @override
  void dispose() {
    widget.relay.onTokenRefresh = null;
    _vid?.dispose();
    super.dispose();
  }

  Future<void> _backgroundDispatch() async {
    try {
      await Future.wait([
        widget.relay.bootstrap().catchError((_) {}),
        widget.tracker.warmup().catchError((_) {}),
      ]);
      await Future.wait([
        widget.tracker.awaitConversion(
            timeout: const Duration(seconds: 6)),
        widget.tracker.awaitDeepLink(),
      ]);
      final body = await widget.tracker.buildPayload(
        locale: Platform.localeName.replaceAll('-', '_'),
        pushToken: widget.relay.token,
      );
      await widget.dispatch.send(body);
    } catch (e) {
      debugPrint('[DGA.VS] background dispatch error: $e');
    }
  }

  void _onTokenRefresh(String token) async {
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.tracker.buildPayload(
      locale: locale,
      pushToken: token,
    );
    widget.dispatch.send(body);
  }

  Future<void> _runFreshMode() async {
    _setStep(_LoadStep.empty);
    final online = await widget.probe.isOnline();
    if (!online) { if (mounted) _openOffline(fresh: true); return; }

    _setStep(_LoadStep.midway);
    await widget.tracker.warmup();
    await Future.wait([
      widget.tracker.awaitConversion(),
      widget.tracker.awaitDeepLink(),
    ]);
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.tracker.buildPayload(
      locale: locale,
      pushToken: widget.relay.token,
    );
    final reply = await widget.dispatch.send(body);

    if (reply.granted && reply.destination != null) {
      await widget.vault.writeMode(RouteMode.web);
      _setStep(_LoadStep.done);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _openContent(reply.destination!);
    } else {
      await widget.vault.writeMode(RouteMode.game);
      _setStep(_LoadStep.done);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _openGame();
    }
  }

  Future<void> _runWebMode({Future<void>? pushFuture}) async {
    final netFuture = widget.probe.isOnline();
    if (pushFuture != null) await Future.wait([netFuture, pushFuture]);
    final online = await netFuture;

    if (!online) {
      _setStep(_LoadStep.done);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _openOffline(fresh: false);
      return;
    }

    final oneShotUrl = await widget.vault.consumeOneShotUrl();
    if (oneShotUrl != null) {
      _setStep(_LoadStep.done);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _openContent(oneShotUrl);
      return;
    }

    final sigFuture = widget.tracker.warmup();
    final savedUrl = await widget.vault.readSavedUrl();
    await sigFuture;
    await Future.wait([
      widget.tracker.awaitConversion(timeout: const Duration(seconds: 5)),
      widget.tracker.awaitDeepLink(),
    ]);
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.tracker.buildPayload(
      locale: locale,
      pushToken: widget.relay.token,
    );
    final reply = await widget.dispatch.send(body);

    _setStep(_LoadStep.done);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    if (reply.granted && reply.destination != null) {
      _openContent(reply.destination!);
      return;
    }
    if (savedUrl != null) {
      _openContent(savedUrl);
    } else {
      _openOffline(fresh: false);
    }
  }

  Future<bool> _tryRestoreWebMode() async {
    final online = await widget.probe.isOnline();
    if (!online) return false;
    await widget.tracker.warmup();
    await Future.wait([
      widget.tracker.awaitConversion(timeout: const Duration(seconds: 8)),
      widget.tracker.awaitDeepLink(),
    ]);
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.tracker.buildPayload(
      locale: locale,
      pushToken: widget.relay.token,
    );
    final reply = await widget.dispatch.send(body);
    if (!(reply.granted && reply.destination != null)) return false;
    await widget.vault.writeMode(RouteMode.web);
    _setStep(_LoadStep.done);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return true;
    _openContent(reply.destination!);
    return true;
  }

  void _openContent(String url) {
    if (_routed) return;
    _routed = true;
    if (widget.vault.needsPushPrompt()) {
      widget.relay.shouldOfferConsent().then((canAsk) {
        if (!mounted) return;
        if (canAsk) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => SignalScreen(
              vault: widget.vault,
              relay: widget.relay,
              probe: widget.probe,
              destination: url,
              onTokenReady: (token) async {
                final locale = Platform.localeName.replaceAll('-', '_');
                final body = await widget.tracker.buildPayload(
                  locale: locale,
                  pushToken: token,
                );
                widget.dispatch.send(body);
              },
            ),
          ));
        } else {
          _directBrowser(url);
        }
      });
    } else {
      _directBrowser(url);
    }
  }

  void _directBrowser(String url) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => VaultBrowser(
        destination: url,
        vault: widget.vault,
        relay: widget.relay,
        probe: widget.probe,
      ),
    ));
  }

  // ── WHITE-PART INTEGRATION POINT ─────────────────────────────────────
  // Called when the hub decides user is organic — launch the game.
  void _openGame() {
    if (_routed) return;
    _routed = true;
    widget.onLaunchGame();
  }

  void _openOffline({required bool fresh}) {
    if (_routed) return;
    _routed = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => OfflineScreen(
        probe: widget.probe,
        retryBuilder: (_) => VaultSplash(
          vault: widget.vault,
          probe: widget.probe,
          tracker: widget.tracker,
          dispatch: widget.dispatch,
          relay: widget.relay,
          onLaunchGame: widget.onLaunchGame,
        ),
      ),
    ));
  }

  String _barAsset() {
    switch (_loadStep) {
      case _LoadStep.empty:
        return 'assets/loading/bar_0.webp';
      case _LoadStep.midway:
        return 'assets/loading/bar_2.webp';
      case _LoadStep.done:
        return 'assets/loading/bar_3.webp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final barAsset = _barAsset();
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;
    final barW = landscape
        ? (mq.size.height * 0.35).clamp(0.0, 160.0)
        : (mq.size.width * 0.70).clamp(0.0, 340.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          AnimatedOpacity(
            opacity: _videoReady ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: _vid != null && _videoReady
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _vid!.value.size.width,
                        height: _vid!.value.size.height,
                        child: VideoPlayer(_vid!),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_videoReady)
            Positioned(
              left: 0,
              right: 0,
              bottom: landscape ? 0 : mq.padding.bottom,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Image.asset(
                    barAsset,
                    key: ValueKey(barAsset),
                    width: barW,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    errorBuilder: (ctx, e, st) =>
                        const SizedBox(height: 32),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
