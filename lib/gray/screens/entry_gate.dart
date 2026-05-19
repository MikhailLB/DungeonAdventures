import 'dart:io';
import 'package:flutter/material.dart';
import '../models/launch_route.dart';
import '../services/install_signal_client.dart';
import '../services/network_radar.dart';
import '../services/pulse_dispatch.dart';
import '../services/remote_gate_client.dart';
import '../services/runtime_cache.dart';
import 'network_pause_screen.dart';
import 'notify_offer_screen.dart';
import 'browser_shell.dart' deferred as shell;

class EntryGate extends StatefulWidget {
  final RuntimeCache cache;
  final NetworkRadar radar;
  final InstallSignalClient signal;
  final RemoteGateClient gate;
  final PulseDispatch pulse;
  final WidgetBuilder fallbackBuilder;

  const EntryGate({
    super.key,
    required this.cache,
    required this.radar,
    required this.signal,
    required this.gate,
    required this.pulse,
    required this.fallbackBuilder,
  });

  @override
  State<EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends State<EntryGate> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _kickoff();
  }

  Future<void> _kickoff() async {
    widget.pulse.onTokenRefresh = _onTokenRefresh;
    await widget.pulse.bootstrap().catchError((_) {});

    final route = widget.cache.readRoute();
    switch (route) {
      case LaunchRoute.web:
        await _runReturningWebFlow();
        break;
      case LaunchRoute.arcade:
        _navigateFallback();
        break;
      case LaunchRoute.pristine:
        await _runFirstLaunchFlow();
        break;
    }
  }

  void _onTokenRefresh(String token) async {
    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.signal.composePayload(
      locale: locale,
      pushToken: token,
    );
    widget.gate.dispatch(body);
  }

  Future<void> _runFirstLaunchFlow() async {
    final hasNet = await widget.radar.hasInternet();
    if (!hasNet) {
      if (!mounted) return;
      _navigateNoSignal(isFirstLaunch: true);
      return;
    }

    await widget.signal.warmup();
    await Future.wait([
      widget.signal.waitForAttribution(),
      widget.signal.waitForDeepLink(),
    ]);

    final locale = Platform.localeName.replaceAll('-', '_');
    final body = await widget.signal.composePayload(
      locale: locale,
      pushToken: widget.pulse.token,
    );
    final resp = await widget.gate.dispatch(body);

    if (resp.ok && resp.url != null) {
      await widget.cache.writeRoute(LaunchRoute.web);
      if (mounted) _navigateToContent(resp.url!);
    } else {
      await widget.cache.writeRoute(LaunchRoute.arcade);
      if (mounted) _navigateFallback();
    }
  }

  Future<void> _runReturningWebFlow() async {
    final hasNet = await widget.radar.hasInternet();
    if (!hasNet) {
      if (!mounted) return;
      _navigateNoSignal(isFirstLaunch: false);
      return;
    }

    final pushUrl = await widget.cache.consumeOneShotPush();
    if (pushUrl != null) {
      if (mounted) _navigateToContent(pushUrl);
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
    final body = await widget.signal.composePayload(
      locale: locale,
      pushToken: widget.pulse.token,
    );
    final resp = await widget.gate.dispatch(body);

    if (!mounted) return;

    if (resp.ok && resp.url != null) {
      _navigateToContent(resp.url!);
      return;
    }
    if (savedUrl != null) {
      _navigateToContent(savedUrl);
    } else {
      _navigateNoSignal(isFirstLaunch: false);
    }
  }

  Future<void> _navigateToContent(String url) async {
    if (_done || !mounted) return;
    _done = true;
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

  void _navigateNoSignal({required bool isFirstLaunch}) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => NetworkPauseScreen(
        retryBuilder: (_) => EntryGate(
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

  void _navigateFallback() {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.fallbackBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    // EntryGate is invisible — it delegates to other screens immediately.
    // The splash widget (DefaultGraySplash or host replacement) is the
    // visible layer while _kickoff() runs.
    return const SizedBox.shrink();
  }
}
