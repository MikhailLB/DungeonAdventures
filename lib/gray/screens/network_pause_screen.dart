import 'dart:io';
import 'package:flutter/material.dart';

Future<bool> _hasInternet() async {
  try {
    final result = await InternetAddress.lookup('google.com')
        .timeout(const Duration(seconds: 4));
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class NetworkPauseScreen extends StatefulWidget {
  final WidgetBuilder retryBuilder;

  const NetworkPauseScreen({super.key, required this.retryBuilder});

  @override
  State<NetworkPauseScreen> createState() => _NetworkPauseScreenState();
}

class _NetworkPauseScreenState extends State<NetworkPauseScreen>
    with SingleTickerProviderStateMixin {
  bool _retrying = false;
  bool _showBanner = false;
  late AnimationController _bannerCtrl;
  late Animation<double> _bannerOpacity;

  @override
  void initState() {
    super.initState();
    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _bannerOpacity = CurvedAnimation(parent: _bannerCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _bannerCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);

    final ok = await _hasInternet();

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: widget.retryBuilder),
      );
      return;
    }

    setState(() => _retrying = false);
    _showTopBanner();
  }

  Future<void> _showTopBanner() async {
    if (_showBanner) return;
    setState(() => _showBanner = true);
    await _bannerCtrl.forward();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _bannerCtrl.reverse();
    if (mounted) setState(() => _showBanner = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bgAsset = isLandscape
        ? 'assets/NoWifi/nowifi_landscape.webp'
        : 'assets/NoWifi/nowifi_portrait.webp';
    final topPad = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            Image.asset(
              bgAsset,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) =>
                  const ColoredBox(color: Color(0xFF0A0B10)),
            ),

            // Retry button
            Positioned(
              left: 0,
              right: 0,
              bottom: size.height * 0.06,
              child: Center(
                child: SizedBox(
                  width: isLandscape
                      ? size.width * 0.32
                      : size.width * 0.68,
                  child: _RetryButton(
                    onTap: _onRetry,
                    retrying: _retrying,
                    compact: isLandscape,
                  ),
                ),
              ),
            ),

            // "Still no internet" top banner
            if (_showBanner)
              Positioned(
                top: topPad + 12,
                left: 20,
                right: 20,
                child: FadeTransition(
                  opacity: _bannerOpacity,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.6),
                      end: Offset.zero,
                    ).animate(_bannerOpacity),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0D00).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFF9900).withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.wifi_off_rounded,
                            color: Color(0xFFFFB300),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Still no internet',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool retrying;
  final bool compact;

  const _RetryButton({
    required this.onTap,
    required this.retrying,
    this.compact = false,
  });

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.35, end: 0.75).animate(_glowCtrl);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
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
            padding: EdgeInsets.symmetric(
                vertical: widget.compact ? 10 : 14),
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
              child: widget.retrying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF1A0A00)),
                      ),
                    )
                  : Text(
                      'Retry',
                      style: TextStyle(
                        color: const Color(0xFF1A0A00),
                        fontSize: widget.compact ? 16 : 18,
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
