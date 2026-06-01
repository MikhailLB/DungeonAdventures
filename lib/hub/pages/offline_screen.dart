import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../infra/net_probe.dart';

class OfflineScreen extends StatefulWidget {
  final WidgetBuilder retryBuilder;
  final NetProbe probe;

  const OfflineScreen({
    super.key,
    required this.retryBuilder,
    required this.probe,
  });

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _hint = false;
  Timer? _hintTimer;
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _press.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    await _press.forward();
    await _press.reverse();
    if (!mounted) return;
    setState(() => _busy = true);
    final online = await widget.probe.isOnline();
    if (!mounted) return;
    if (!online) {
      _hintTimer?.cancel();
      setState(() { _busy = false; _hint = true; });
      _hintTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _hint = false);
      });
      return;
    }
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: widget.retryBuilder));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.size.width > mq.size.height;
    final bgAsset = landscape
        ? 'assets/NoWifi/nowifi_landscape.webp'
        : 'assets/NoWifi/nowifi_portrait.webp';
    final btnW = landscape
        ? (mq.size.width * 0.24).clamp(200.0, 340.0)
        : (mq.size.width * 0.52).clamp(180.0, 300.0);
    final btnBottom = landscape ? mq.size.height * 0.05 : mq.size.height * 0.18;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(bgAsset, fit: BoxFit.cover),
          Positioned(
            left: 0, right: 0, bottom: btnBottom,
            child: Center(
              child: AnimatedBuilder(
                animation: _press,
                builder: (_, child) => Transform.scale(
                  scale: 1.0 - 0.05 * _press.value, child: child,
                ),
                child: GestureDetector(
                  onTap: _busy ? null : _retry,
                  child: SizedBox(
                    width: btnW,
                    child: AspectRatio(
                      aspectRatio: 3.6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: _busy
                              ? null
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFFEEB454),
                                    Color(0xFFB87322),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: _busy
                              ? const Color(0xFFEEB454).withValues(alpha: 0.3)
                              : null,
                          border: Border.all(
                              color: const Color(0xFF1E130A), width: 2.5),
                          boxShadow: _busy
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFFEEB454)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF1E130A),
                                  ),
                                )
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh_rounded,
                                        color: Color(0xFF1E130A), size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      'Retry',
                                      style: TextStyle(
                                        color: Color(0xFF1E130A),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: landscape ? Alignment.topCenter : Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: landscape ? 12 : 16,
                ),
                child: AnimatedOpacity(
                  opacity: _hint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Text(
                        'Still no internet — please try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
