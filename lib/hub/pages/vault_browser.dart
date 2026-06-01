import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../infra/masked_agent.dart';
import '../infra/net_probe.dart';
import '../infra/dungeon_vault.dart';
import '../infra/signal_relay.dart';
import 'offline_screen.dart';

/// In-app WebView browser with immersive mode, keyboard scroll fixes and
/// safe-area compensation.
class VaultBrowser extends StatefulWidget {
  final String destination;
  final DungeonVault vault;
  final SignalRelay relay;
  final NetProbe probe;
  final VoidCallback? onFirstPaint;

  const VaultBrowser({
    super.key,
    required this.destination,
    required this.vault,
    required this.relay,
    required this.probe,
    this.onFirstPaint,
  });

  @override
  State<VaultBrowser> createState() => _VaultBrowserState();
}

class _VaultBrowserState extends State<VaultBrowser>
    with WidgetsBindingObserver {
  late final WebViewController _wv;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _offlineRouted = false;
  String? _lastMainFrameUrl;
  int _redirectRetries = 0;
  bool _firstPaintFired = false;
  Widget? _fullscreenOverlay;
  void Function()? _hideOverlay;

  void _applyImmersive() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyImmersive();
      _drainStash();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyImmersive();

    late final PlatformWebViewControllerCreationParams params;
    if (Platform.isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (Platform.isAndroid) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _wv = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(maskedAgent.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(_buildDelegate());

    _configurePlatform();
    _wv.loadRequest(Uri.parse(widget.destination));

    widget.relay.onPushUrl = (url) {
      if (!mounted) return;
      try {
        final uri = Uri.parse(url);
        if (uri.hasScheme) _wv.loadRequest(uri);
      } catch (_) {}
    };

    _connSub = widget.probe.onChange.listen((statuses) {
      if (statuses.every((s) => s == ConnectivityResult.none)) {
        _maybeRouteOffline();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _drainStash());
  }

  Future<void> _drainStash() async {
    final url = await widget.vault.consumeOneShotUrl();
    if (url != null && url.isNotEmpty && mounted) {
      try {
        final uri = Uri.parse(url);
        if (uri.hasScheme) _wv.loadRequest(uri);
      } catch (_) {}
    }
  }

  NavigationDelegate _buildDelegate() {
    return NavigationDelegate(
      onPageStarted: (_) {},
      onPageFinished: (_) {
        _redirectRetries = 0;
        _applyViewportFix();
        _applyKeyboardScroll();
        _applyAntiZoom();
        _applyMediaAutoplay();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          _wv.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'if(window.visualViewport)'
            '  window.visualViewport.dispatchEvent(new Event("resize"));',
          );
          _applyViewportFix();
        });
        if (!_firstPaintFired) {
          _firstPaintFired = true;
          Future.delayed(const Duration(milliseconds: 600), () {
            try { widget.onFirstPaint?.call(); } catch (_) {}
          });
        }
      },
      onWebResourceError: (err) {
        if (err.isForMainFrame != true) return;
        if (err.errorCode == -999) return; // NSURLErrorCancelled — not a real error
        final desc = err.description.toLowerCase();
        final loop = desc.contains('too_many_redirects') ||
            desc.contains('too many redirects') ||
            err.errorCode == -1007 ||
            err.errorCode == -9;
        if (loop && _lastMainFrameUrl != null && _redirectRetries < 3) {
          _redirectRetries++;
          _wv.loadRequest(Uri.parse(_lastMainFrameUrl!));
          return;
        }
        _maybeRouteOffline();
      },
      onHttpError: (_) {},
      onNavigationRequest: (req) {
        final uri = Uri.tryParse(req.url);
        if (uri == null) return NavigationDecision.prevent;
        final s = uri.scheme;
        if (s == 'http' || s == 'https' || s == 'about' ||
            s == 'data' || s == 'blob') {
          if (req.isMainFrame) _lastMainFrameUrl = req.url;
          return NavigationDecision.navigate;
        }
        _launchExternal(uri);
        return NavigationDecision.prevent;
      },
    );
  }

  void _configurePlatform() {
    if (Platform.isIOS && _wv.platform is WebKitWebViewController) {
      (_wv.platform as WebKitWebViewController)
          .setAllowsBackForwardNavigationGestures(true);
    }
    if (Platform.isAndroid && _wv.platform is AndroidWebViewController) {
      final android = _wv.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
      android.setOnShowFileSelector(_pickFiles);
      android.setCustomWidgetCallbacks(
        onShowCustomWidget: (w, hide) {
          _hideOverlay = hide;
          if (mounted) setState(() => _fullscreenOverlay = w);
        },
        onHideCustomWidget: () {
          _hideOverlay = null;
          if (mounted) setState(() => _fullscreenOverlay = null);
        },
      );
      final cookies = AndroidWebViewCookieManager(
        AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      );
      cookies.setAcceptThirdPartyCookies(android, true);
    }
  }

  Future<List<String>> _pickFiles(FileSelectorParams p) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: p.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (result == null) return const [];
      return result.files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _maybeRouteOffline() async {
    if (_offlineRouted) return;
    final ok = await widget.probe.isOnline();
    if (ok || !mounted) return;
    _offlineRouted = true;
    final current = await _wv.currentUrl() ?? widget.destination;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => OfflineScreen(
        probe: widget.probe,
        retryBuilder: (_) => VaultBrowser(
          destination: current,
          vault: widget.vault,
          relay: widget.relay,
          probe: widget.probe,
        ),
      ),
    ));
  }

  void _launchExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ── JS injections (unique __dga* sentinel variables) ────────────────

  void _applyViewportFix() {
    _wv.runJavaScript(r'''
(function(){
  if(window.__dgaSa)return; window.__dgaSa=true;
  var ID='__dgaSa';
  var CSS=':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;'
    +'--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;'
    +'--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;}'
    +'html,body,#__nuxt,#__layout,#app,#root,.gameview-mobile-header{'
    +'padding-top:0!important;padding-left:0!important;padding-right:0!important;margin-top:0!important;}';
  function kbOpen(){return window.visualViewport&&window.visualViewport.height<window.innerHeight*0.75;}
  function apply(){
    if(kbOpen())return;
    var h=document.head||document.documentElement; if(!h)return;
    var vp=document.querySelector('meta[name="viewport"]');
    if(vp&&!/viewport-fit\s*=\s*contain/i.test(vp.getAttribute('content')||'')){
      var c=(vp.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      vp.setAttribute('content',c+(c?', ':'')+' viewport-fit=contain');
    }
    var s=document.getElementById(ID);
    if(!s){s=document.createElement('style');s.id=ID;h.appendChild(s);}
    if(s.textContent!==CSS)s.textContent=CSS;
    if(h.lastElementChild!==s)h.appendChild(s);
  }
  apply();
  ['pushState','replaceState'].forEach(function(n){
    var o=history[n];history[n]=function(){var r=o.apply(this,arguments);setTimeout(apply,150);setTimeout(apply,600);return r;};
  });
  window.addEventListener('popstate',function(){setTimeout(apply,150);});
  setInterval(apply,2500);
})();
''');
  }

  void _applyKeyboardScroll() {
    _wv.runJavaScript(r'''
(function(){
  if(window.__dgaKb)return; window.__dgaKb=true;
  function iL(n){return n&&(n.tagName==='INPUT'||n.tagName==='TEXTAREA'||n.isContentEditable);}
  function roll(){
    var el=document.activeElement; if(!iL(el))return;
    var vp=window.visualViewport;
    if(vp){var r=el.getBoundingClientRect();
      if(r.bottom>vp.offsetTop+vp.height-20||r.top<vp.offsetTop)
        el.scrollIntoView({behavior:'auto',block:'nearest'});
    } else { el.scrollIntoView({behavior:'auto',block:'nearest'}); }
  }
  document.addEventListener('focusin',function(e){if(iL(e.target))setTimeout(roll,350);});
  if(window.visualViewport){
    var prev=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height;if(h<prev)setTimeout(roll,120);prev=h;
    });
  }
})();
''');
  }

  void _applyAntiZoom() {
    if (!Platform.isIOS) return;
    _wv.runJavaScript(r'''
(function(){
  if(window.__dgaAz)return; window.__dgaAz=true;
  var s=document.createElement('style'); s.id='__dgaAz';
  s.textContent='input,textarea,select,[contenteditable=true]{font-size:16px!important;}';
  (document.head||document.documentElement).appendChild(s);
})();
''');
  }

  void _applyMediaAutoplay() {
    _wv.runJavaScript(r'''
(function(){
  if(window.__dgaVid)return; window.__dgaVid=true;
  function prep(v){
    try{
      v.setAttribute('playsinline','');v.setAttribute('webkit-playsinline','');
      v.playsInline=true;v.muted=true;v.defaultMuted=true;v.autoplay=true;
      var p=v.play&&v.play();if(p&&p.catch)p.catch(function(){});
    }catch(_){}
  }
  function sweep(r){try{var l=(r||document).querySelectorAll('video');for(var i=0;i<l.length;i++)prep(l[i]);}catch(_){}}
  sweep(document);
  document.addEventListener('touchend',function(){sweep(document);},{passive:true});
  var mo=new MutationObserver(function(recs){
    for(var i=0;i<recs.length;i++){var nodes=recs[i].addedNodes||[];
      for(var j=0;j<nodes.length;j++){var n=nodes[j];if(!n||n.nodeType!==1)continue;
        if(n.tagName==='VIDEO')prep(n);sweep(n);}
    }
  });
  mo.observe(document.documentElement,{childList:true,subtree:true});
  setInterval(function(){sweep(document);},1500);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    widget.relay.onPushUrl = null;
    SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual, overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _fullscreenOverlay != null) _hideOverlay?.call();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: safe.top,
                bottom: safe.bottom,
                left: safe.left,
                right: safe.right,
              ),
              child: WebViewWidget(controller: _wv),
            ),
            if (_fullscreenOverlay != null)
              Positioned.fill(child: _fullscreenOverlay!),
          ],
        ),
      ),
    );
  }
}
