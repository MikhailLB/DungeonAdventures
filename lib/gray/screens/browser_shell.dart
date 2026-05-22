import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/network_radar.dart';
import '../services/runtime_cache.dart';
import '../services/pulse_dispatch.dart';
import '../services/secure_http.dart';
import 'network_pause_screen.dart';

Future<void> prepareContentEngine() async {}

class BrowserShell extends StatefulWidget {
  final String url;
  final RuntimeCache cache;
  final PulseDispatch pulse;
  final NetworkRadar radar;

  const BrowserShell({
    super.key,
    required this.url,
    required this.cache,
    required this.pulse,
    required this.radar,
  });

  @override
  State<BrowserShell> createState() => _BrowserShellState();
}

class _BrowserShellState extends State<BrowserShell>
    with WidgetsBindingObserver {
  late final WebViewController _wv;
  bool _loading = true;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _showingOffline = false;
  String? _lastRedirectUrl;
  int _redirectRetries = 0;

  void _applyUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyUI();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyUI();

    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(secureHttp.userAgent)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
          _redirectRetries = 0;
          _injectSafeAreaPatch();
          _injectKeyboardScroll();
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame != true) return;
          final d = e.description.toLowerCase();
          final tooMany = d.contains('too_many_redirects') ||
              d.contains('too many redirects') ||
              e.errorCode == -1007 ||
              e.errorCode == -9;
          if (tooMany && _lastRedirectUrl != null && _redirectRetries < 3) {
            _redirectRetries++;
            _wv.loadRequest(Uri.parse(_lastRedirectUrl!));
            return;
          }
          _checkOffline();
        },
        onHttpError: (_) {},
        onNavigationRequest: (req) {
          final uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          final s = uri.scheme;
          if (s == 'http' || s == 'https' || s == 'about' || s == 'data' || s == 'blob') {
            if (req.isMainFrame) _lastRedirectUrl = req.url;
            return NavigationDecision.navigate;
          }
          _openExternal(uri);
          return NavigationDecision.prevent;
        },
      ))
      ..enableZoom(false);

    _configurePlatform();
    _wv.loadRequest(Uri.parse(widget.url));

    widget.pulse.onPushDestination = (url) {
      if (mounted) _wv.loadRequest(Uri.parse(url));
    };

    _connSub = widget.radar.onChange.listen((results) {
      if (results.every((r) => r == ConnectivityResult.none)) _checkOffline();
    });
  }

  Future<void> _checkOffline() async {
    if (_showingOffline) return;
    final has = await widget.radar.hasInternet();
    if (has || !mounted) return;
    _showingOffline = true;
    final cur = await _wv.currentUrl() ?? widget.url;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => NetworkPauseScreen(
        retryBuilder: (_) => BrowserShell(
          url: cur,
          cache: widget.cache,
          pulse: widget.pulse,
          radar: widget.radar,
        ),
      ),
    ));
  }

  void _configurePlatform() {
    if (Platform.isAndroid && _wv.platform is AndroidWebViewController) {
      final ac = _wv.platform as AndroidWebViewController;
      ac.setMediaPlaybackRequiresUserGesture(false);
      ac.setOnShowFileSelector(_filePicker);
      final cm = AndroidWebViewCookieManager(
        AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      );
      cm.setAcceptThirdPartyCookies(ac, true);
    }
  }

  Future<List<String>> _filePicker(FileSelectorParams p) async {
    try {
      final r = await FilePicker.pickFiles(
        allowMultiple: p.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (r != null && r.files.isNotEmpty) {
        return r.files
            .where((f) => f.path != null)
            .map((f) => Uri.file(f.path!).toString())
            .toList();
      }
    } catch (_) {}
    return [];
  }

  void _injectKeyboardScroll() {
    _wv.runJavaScript('''
(function(){
  if(window.__kbFixApplied)return;window.__kbFixApplied=true;
  function isInput(el){return el&&(el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable);}
  function doScroll(){var el=document.activeElement;if(!isInput(el))return;var vp=window.visualViewport;if(vp){var rect=el.getBoundingClientRect();var vpB=vp.offsetTop+vp.height;if(rect.bottom>vpB-20||rect.top<vp.offsetTop){el.scrollIntoView({behavior:'smooth',block:'center'});}}else{el.scrollIntoView({behavior:'smooth',block:'center'});}}
  document.addEventListener('focusin',function(e){if(isInput(e.target)){setTimeout(doScroll,250);setTimeout(doScroll,500);setTimeout(doScroll,800);}});
  if(window.visualViewport){var prevH=window.visualViewport.height;window.visualViewport.addEventListener('resize',function(){var h=window.visualViewport.height;if(h<prevH){setTimeout(doScroll,80);setTimeout(doScroll,300);}prevH=h;});}
})();
''');
  }

  void _injectSafeAreaPatch() {
    _wv.runJavaScript(r'''
(function(){
  if(window.__saRunning)return;window.__saRunning=true;
  var ID='__sa';var T=':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;}html,body,#__nuxt,#__layout,#app,#root,.gameview-mobile-header{padding-top:0!important;padding-left:0!important;padding-right:0!important;margin-top:0!important;}';
  function apply(){var h=document.head||document.documentElement;if(!h)return;var m=document.querySelector('meta[name="viewport"]');if(m&&!/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content')||'')){var c=(m.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();m.setAttribute('content',c+(c?', ':'')+' viewport-fit=contain');}var s=document.getElementById(ID);if(!s){s=document.createElement('style');s.id=ID;h.appendChild(s);}if(s.textContent!==T)s.textContent=T;if(h.lastElementChild!==s)h.appendChild(s);}
  apply();
  ['pushState','replaceState'].forEach(function(fn){var o=history[fn];history[fn]=function(){var r=o.apply(this,arguments);setTimeout(apply,80);setTimeout(apply,400);return r;};});
  window.addEventListener('popstate',function(){setTimeout(apply,80);});
  setInterval(apply,2500);
})();
''');
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    widget.pulse.onPushDestination = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<bool> _onPop() async {
    if (await _wv.canGoBack()) {
      await _wv.goBack();
      return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onPop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              WebViewWidget(controller: _wv),
              if (_loading)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFFC853)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
