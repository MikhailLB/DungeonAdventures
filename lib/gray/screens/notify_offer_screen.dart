import 'package:flutter/material.dart';
import '../config/runtime_brand.dart';
import '../services/runtime_cache.dart';
import '../services/pulse_dispatch.dart';
import '../services/network_radar.dart';
import 'browser_shell.dart' deferred as shell;

class NotifyOfferScreen extends StatefulWidget {
  final RuntimeCache cache;
  final PulseDispatch pulse;
  final NetworkRadar radar;
  final String contentUrl;

  const NotifyOfferScreen({
    super.key,
    required this.cache,
    required this.pulse,
    required this.radar,
    required this.contentUrl,
  });

  @override
  State<NotifyOfferScreen> createState() => _NotifyOfferScreenState();
}

class _NotifyOfferScreenState extends State<NotifyOfferScreen> {
  void _onAccept() async {
    final granted = await widget.pulse.askConsent();
    if (!mounted) return;
    if (!granted) {
      final skipUntil = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
          RuntimeBrand.notificationRetryDelaySeconds;
      await widget.cache.setNotifSkipUntil(skipUntil);
    }
    _goToContent();
  }

  void _onSkip() async {
    final skipUntil = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        RuntimeBrand.notificationRetryDelaySeconds;
    await widget.cache.setNotifSkipUntil(skipUntil);
    if (!mounted) return;
    _goToContent();
  }

  Future<void> _goToContent() async {
    await shell.loadLibrary();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => shell.BrowserShell(
          url: widget.contentUrl,
          cache: widget.cache,
          pulse: widget.pulse,
          radar: widget.radar,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bgAsset = isLandscape
        ? 'assets/Notifications/notification_landscape.webp'
        : 'assets/Notifications/notification_portrait.webp';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(bgAsset, fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const ColoredBox(color: Color(0xFF0A0B10))),

            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * 0.04,
              child: isLandscape
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: size.width * 0.32,
                          child: _AcceptBtn(onTap: _onAccept, compact: true),
                        ),
                        const SizedBox(height: 8),
                        _SkipBtn(onTap: _onSkip, compact: true),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: SizedBox(
                            width: size.width * 0.68,
                            child: _AcceptBtn(onTap: _onAccept),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SkipBtn(onTap: _onSkip),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptBtn extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const _AcceptBtn({required this.onTap, this.compact = false});
  @override
  State<_AcceptBtn> createState() => _AcceptBtnState();
}

class _AcceptBtnState extends State<_AcceptBtn>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glow;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _glowAnim =
        Tween<double>(begin: 0.35, end: 0.75).animate(_glow);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (context, child) => AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: widget.compact ? 10 : 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _pressed
                    ? const [Color(0xFFE6A800), Color(0xFFCC8800)]
                    : const [Color(0xFFFFCC00), Color(0xFFFF9900)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF9900)
                      .withValues(alpha: _pressed ? 0.2 : _glowAnim.value),
                  blurRadius: _pressed ? 8 : 14 + _glowAnim.value * 18,
                  spreadRadius: _pressed ? 0 : _glowAnim.value * 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Accept',
                style: TextStyle(
                  color: const Color(0xFF1A0A00),
                  fontSize: widget.compact ? 16 : 20,
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

class _SkipBtn extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const _SkipBtn({required this.onTap, this.compact = false});
  @override
  State<_SkipBtn> createState() => _SkipBtnState();
}

class _SkipBtnState extends State<_SkipBtn> {
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
        opacity: _pressed ? 0.5 : 0.85,
        duration: const Duration(milliseconds: 80),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: widget.compact ? 4 : 8),
          child: Center(
            child: Text(
              'Skip',
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.compact ? 16 : 22,
                fontWeight: FontWeight.w700,
                shadows: const [
                  Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
