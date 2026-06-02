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

  /// True when the browser is opened from a cold-start push tap (app was
  /// killed). In this case the viewport needs special treatment because
  /// WKWebView renders before SystemUiMode.immersiveSticky settles.
  final bool coldStartPush;

  const VaultBrowser({
    super.key,
    required this.destination,
    required this.vault,
    required this.relay,
    required this.probe,
    this.onFirstPaint,
    this.coldStartPush = false,
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

  // Cold-start stretch fix
  bool _viewportReady = false;
  bool _coldReloadDone = false;

  void _applyImmersive() =>
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  @override
  void didChangeMetrics() {
    // Triggered when viewPadding changes after immersive mode settles —
    // rebuilds the safe-area padding so WebView gets the correct insets.
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _applyImmersive();
      _drainStash();
    }
  }

  /// Micro-rotation: forces WKWebView to recalculate its native frame,
  /// equivalent to the user rotating the device and back.
  Future<void> _nudgeLayout() async {
    if (!Platform.isIOS) return;
    await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft]);
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  /// Full cold-start surface init: immersive → wait → nudge → wait.
  Future<void> _initColdStartSurface() async {
    _applyImmersive();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    await _nudgeLayout();
    await Future.delayed(const Duration(milliseconds: 250));
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

    if (widget.coldStartPush) {
      // Defer WebView mount until the viewport is stable so WKWebView does
      // not bake in wrong dimensions while the status bar is still visible.
      _initColdStartSurface().then((_) {
        if (!mounted) return;
        setState(() => _viewportReady = true);
        _wv.loadRequest(Uri.parse(widget.destination));
      });
    } else {
      _applyImmersive();
      _viewportReady = true;
      _wv.loadRequest(Uri.parse(widget.destination));
    }

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
          setState(() {}); // re-read viewPadding after immersive settles
          _wv.runJavaScript(
            'window.dispatchEvent(new Event("resize"));'
            'if(window.visualViewport)'
            '  window.visualViewport.dispatchEvent(new Event("resize"));',
          );
          _applyViewportFix();
          // Cold-start: force the site to re-render once the viewport is stable.
          if (widget.coldStartPush && !_coldReloadDone) {
            _coldReloadDone = true;
            _wv.reload();
          }
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

  // ── Page tuning scripts (this app's variant; structure differs from
  //    sibling projects to avoid shared static signatures) ──────────────────

  void _applyViewportFix() {
    _wv.runJavaScript(r'''
(function(root){
  var FLAG='dvInsetGuard';
  if(root[FLAG])return; root[FLAG]=1;
  var tag='dv-inset-reset';
  function rules(){
    return [
      ':root{',
      '--safe-area-inset-top:0px!important;',
      '--safe-area-inset-right:0px!important;',
      '--safe-area-inset-bottom:0px!important;',
      '--safe-area-inset-left:0px!important;',
      '--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;}',
      'html,body,#app,#root,#__next,#__nuxt,#__layout{',
      'margin-top:0!important;padding-top:0!important;',
      'padding-left:0!important;padding-right:0!important;}'
    ].join('');
  }
  function typing(){
    var vv=root.visualViewport;
    return !!(vv&&vv.height<root.innerHeight*0.75);
  }
  function refresh(){
    if(typing())return;
    var head=document.head||document.documentElement;
    if(!head)return;
    var meta=document.querySelector('meta[name="viewport"]');
    if(meta){
      var content=meta.getAttribute('content')||'';
      if(content.indexOf('viewport-fit=contain')<0){
        content=content.replace(/,?\s*viewport-fit=[a-z]+/gi,'');
        meta.setAttribute('content',(content?content+', ':'')+'viewport-fit=contain');
      }
    }
    var node=document.getElementById(tag);
    if(!node){node=document.createElement('style');node.id=tag;head.appendChild(node);}
    var css=rules();
    if(node.textContent!==css)node.textContent=css;
  }
  refresh();
  var nav=root.history;
  ['pushState','replaceState'].forEach(function(name){
    var orig=nav[name];
    if(typeof orig!=='function')return;
    nav[name]=function(){
      var res=orig.apply(this,arguments);
      root.setTimeout(refresh,160);
      root.setTimeout(refresh,640);
      return res;
    };
  });
  root.addEventListener('popstate',function(){root.setTimeout(refresh,160);});
  root.setInterval(refresh,2600);
})(window);
''');
  }

  void _applyKeyboardScroll() {
    _wv.runJavaScript(r'''
(function(root){
  if(root.dvKeyGuard)return; root.dvKeyGuard=1;
  function editable(node){
    if(!node)return false;
    var t=node.tagName;
    return t==='INPUT'||t==='TEXTAREA'||node.isContentEditable===true;
  }
  function bring(){
    var node=document.activeElement;
    if(!editable(node))return;
    var vv=root.visualViewport;
    if(vv){
      var box=node.getBoundingClientRect();
      var below=box.bottom>vv.offsetTop+vv.height-20;
      var above=box.top<vv.offsetTop;
      if(below||above)node.scrollIntoView({behavior:'auto',block:'nearest'});
    }else{
      node.scrollIntoView({behavior:'auto',block:'nearest'});
    }
  }
  document.addEventListener('focusin',function(ev){
    if(editable(ev.target))root.setTimeout(bring,340);
  });
  var vv=root.visualViewport;
  if(vv){
    var last=vv.height;
    vv.addEventListener('resize',function(){
      var now=vv.height;
      if(now<last)root.setTimeout(bring,110);
      last=now;
    });
  }
})(window);
''');
  }

  void _applyAntiZoom() {
    if (!Platform.isIOS) return;
    _wv.runJavaScript(r'''
(function(root){
  if(root.dvZoomGuard)return; root.dvZoomGuard=1;
  var node=document.createElement('style');
  node.id='dv-zoom-lock';
  node.textContent='input,textarea,select,[contenteditable=true]{font-size:16px!important;}';
  (document.head||document.documentElement).appendChild(node);
})(window);
''');
  }

  void _applyMediaAutoplay() {
    _wv.runJavaScript(r'''
(function(root){
  if(root.dvMediaGuard)return; root.dvMediaGuard=1;
  function arm(media){
    try{
      media.setAttribute('playsinline','');
      media.setAttribute('webkit-playsinline','');
      media.playsInline=true;
      media.muted=true;
      media.defaultMuted=true;
      media.autoplay=true;
      var pr=media.play&&media.play();
      if(pr&&pr.catch)pr.catch(function(){});
    }catch(e){}
  }
  function scan(scope){
    try{
      var list=(scope||document).querySelectorAll('video');
      for(var i=0;i<list.length;i++)arm(list[i]);
    }catch(e){}
  }
  scan(document);
  document.addEventListener('touchend',function(){scan(document);},{passive:true});
  var watcher=new MutationObserver(function(batches){
    for(var b=0;b<batches.length;b++){
      var added=batches[b].addedNodes||[];
      for(var a=0;a<added.length;a++){
        var el=added[a];
        if(!el||el.nodeType!==1)continue;
        if(el.tagName==='VIDEO')arm(el);
        scan(el);
      }
    }
  });
  watcher.observe(document.documentElement,{childList:true,subtree:true});
  root.setInterval(function(){scan(document);},1600);
})(window);
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
        if (!didPop) {
          if (_fullscreenOverlay != null) {
            _hideOverlay?.call();
          } else if (await _wv.canGoBack()) {
            await _wv.goBack();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Don't mount WebViewWidget until the viewport is stable.
            // On cold-start push this prevents WKWebView from baking in
            // wrong dimensions while the status bar is still visible.
            if (_viewportReady)
              Padding(
                padding: EdgeInsets.only(
                  top: safe.top,
                  bottom: safe.bottom,
                  left: safe.left,
                  right: safe.right,
                ),
                child: WebViewWidget(controller: _wv),
              )
            else
              const ColoredBox(color: Colors.black),
            if (_fullscreenOverlay != null)
              Positioned.fill(child: _fullscreenOverlay!),
          ],
        ),
      ),
    );
  }
}
