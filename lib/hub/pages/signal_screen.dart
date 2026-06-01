import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/hub_config.dart';
import '../infra/dungeon_vault.dart';
import '../infra/net_probe.dart';
import '../infra/signal_relay.dart';
import 'vault_browser.dart';

/// Push permission offer screen — shows branded Notifications background image
/// (portrait or landscape) with Accept / Skip buttons.
class SignalScreen extends StatefulWidget {
  final DungeonVault vault;
  final SignalRelay relay;
  final NetProbe probe;
  final String destination;
  final Future<void> Function(String token)? onTokenReady;

  const SignalScreen({
    super.key,
    required this.vault,
    required this.relay,
    required this.probe,
    required this.destination,
    this.onTokenReady,
  });

  @override
  State<SignalScreen> createState() => _SignalScreenState();
}

class _SignalScreenState extends State<SignalScreen>
    with TickerProviderStateMixin {
  bool _busy = false;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final granted = await widget.relay.askConsent();
      if (granted) {
        final token = await widget.relay.refreshTokenAfterConsent();
        if (token != null && token.isNotEmpty) {
          await widget.onTokenReady?.call(token);
        }
      } else {
        await _setCooldown();
      }
      _openBrowser();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    await _setCooldown();
    _openBrowser();
  }

  Future<void> _setCooldown() async {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        DungeonHubConfig.pushCooldownSeconds;
    await widget.vault.writePushCooldown(until);
  }

  void _openBrowser() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => VaultBrowser(
        destination: widget.destination,
        vault: widget.vault,
        relay: widget.relay,
        probe: widget.probe,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.size.width > mq.size.height;
    final bgAsset = landscape
        ? 'assets/Notifications/notification_landscape.webp'
        : 'assets/Notifications/notification_portrait.webp';
    final btnW = landscape
        ? (mq.size.width * 0.30).clamp(220.0, 360.0)
        : mq.size.width * 0.76;
    final bottomGap = mq.size.height * (landscape ? 0.05 : 0.07);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(bgAsset, fit: BoxFit.cover),
            SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 0, right: 0, bottom: bottomGap,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AllowButton(
                          width: btnW,
                          busy: _busy,
                          glow: _glow,
                          onTap: _accept,
                          compact: landscape,
                        ),
                        SizedBox(height: mq.size.height * 0.022),
                        _DismissButton(onTap: _skip, compact: landscape),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllowButton extends StatefulWidget {
  final double width;
  final bool busy;
  final bool compact;
  final AnimationController glow;
  final VoidCallback onTap;

  const _AllowButton({
    required this.width,
    required this.busy,
    required this.glow,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_AllowButton> createState() => _AllowButtonState();
}

class _AllowButtonState extends State<_AllowButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = widget.compact ? 16.0 : 20.0;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _press.forward();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _press.reverse();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, widget.glow]),
        builder: (context, child) => Transform.scale(
          scale: 1.0 - 0.04 * _press.value,
          child: Container(
            width: widget.width,
            padding: EdgeInsets.symmetric(
                vertical: widget.compact ? 12 : 17),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _pressed
                    ? [const Color(0xFFB87322), const Color(0xFF8A5219)]
                    : [const Color(0xFFEEB454), const Color(0xFFB87322)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEEB454).withValues(
                      alpha: _pressed
                          ? 0.2
                          : 0.30 + 0.25 * widget.glow.value),
                  blurRadius: _pressed ? 6 : 16 + widget.glow.value * 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: widget.busy
                  ? SizedBox(
                      width: fontSize + 4,
                      height: fontSize + 4,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF1E130A),
                      ),
                    )
                  : Text(
                      'Allow',
                      style: TextStyle(
                        color: const Color(0xFF1E130A),
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;

  const _DismissButton({required this.onTap, this.compact = false});

  @override
  State<_DismissButton> createState() => _DismissButtonState();
}

class _DismissButtonState extends State<_DismissButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.45 : 0.82,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 4 : 8),
          child: Text(
            'Not Now',
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.compact ? 16 : 22,
              fontWeight: FontWeight.w700,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}
