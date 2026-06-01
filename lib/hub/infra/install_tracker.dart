import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../config/endpoint_vault.dart';
import '../config/hub_config.dart';
import 'masked_agent.dart';
import 'hub_log.dart';

/// AppsFlyer SDK wrapper — provides install attribution data for the hub
/// dispatch payload.
class InstallTracker {
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _conversion;
  Map<String, dynamic>? _deepLink;
  Map<String, dynamic>? _reopen;

  final Completer<Map<String, dynamic>> _convDone = Completer();
  final Completer<void> _dlDone = Completer();

  bool _launched = false;
  Future<void>? _warmFuture;

  bool get launched => _launched;

  Future<void> warmup() => _warmFuture ??= _doWarmup();

  Future<void> _doWarmup() async {
    if (_launched) return;
    final devKey = DungeonHubConfig.installKey;
    hubLog(() => '[DGA.IT] warmup devKeyLen=${devKey.length}');
    if (devKey.isEmpty) {
      _launched = true;
      if (!_convDone.isCompleted) _convDone.complete({});
      if (!_dlDone.isCompleted) _dlDone.complete();
      return;
    }
    _launched = true;
    try {
      if (Platform.isIOS) await _requestAtt();
      final opts = AppsFlyerOptions(
        afDevKey: devKey,
        appId: DungeonHubConfig.analyticsAppId,
        showDebug: kDebugMode,
        timeToWaitForATTUserAuthorization: 4,
      );
      _sdk = AppsflyerSdk(opts);
      _sdk!.onInstallConversionData(_onConversion);
      _sdk!.onAppOpenAttribution(_onReopen);
      _sdk!.onDeepLinking(_onDeepLink);
      await _sdk!.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
      hubLog(() => '[DGA.IT] initSdk OK');
    } catch (err, st) {
      hubLog(() => '[DGA.IT] warmup error: $err\n$st');
      if (!_convDone.isCompleted) _convDone.complete({});
      if (!_dlDone.isCompleted) _dlDone.complete();
    }
  }

  Future<void> _requestAtt() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status != TrackingStatus.notDetermined) return;
      await WidgetsBinding.instance.endOfFrame;
      await Future.delayed(const Duration(milliseconds: 300));
      await AppTrackingTransparency.requestTrackingAuthorization();
    } catch (err) {
      hubLog(() => '[DGA.IT] ATT skipped: $err');
    }
  }

  Map<String, dynamic> _flatten(dynamic raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final inner = m['payload'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return m;
  }

  void _onConversion(dynamic raw) async {
    final data = _flatten(raw);
    hubLog(() => '[DGA.IT] conversion ${jsonEncode(data)}');
    if (data['af_status'] == 'Organic') {
      await Future.delayed(
          Duration(seconds: DungeonHubConfig.organicRetrySeconds));
      final retry = await _refreshGcd();
      _conversion = retry ?? data;
    } else {
      _conversion = data;
    }
    if (!_convDone.isCompleted) _convDone.complete(_conversion);
  }

  void _onReopen(dynamic raw) => _reopen = _flatten(raw);

  void _onDeepLink(DeepLinkResult r) {
    if (r.deepLink != null) _deepLink = r.deepLink!.clickEvent;
    if (!_dlDone.isCompleted) _dlDone.complete();
  }

  Future<Map<String, dynamic>?> _refreshGcd() async {
    try {
      final uid = await deviceId();
      if (uid == null) return null;
      final appId = Platform.isIOS
          ? DungeonHubConfig.analyticsAppId
          : DungeonHubConfig.bundleId;
      final url = hubGcdUrl(appId, uid);
      if (url.isEmpty) return null;
      final resp = await maskedAgent.get(
        Uri.parse(url),
        headers: {'authorization': 'Bearer ${DungeonHubConfig.installKey}'},
      ).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final d = jsonDecode(resp.body);
        if (d is Map<String, dynamic>) return d;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> awaitConversion({
    Duration timeout = const Duration(seconds: 7),
  }) =>
      _convDone.future.timeout(timeout, onTimeout: () => {});

  Future<void> awaitDeepLink({
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _dlDone.future.timeout(timeout, onTimeout: () {});

  Future<String?> deviceId() async {
    if (_sdk == null) return null;
    try { return await _sdk!.getAppsFlyerUID(); } catch (_) { return null; }
  }

  Future<Map<String, dynamic>> buildPayload({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};
    if (_conversion != null) body.addAll(_conversion!);
    if (_deepLink != null) {
      _deepLink!.forEach((k, v) => body.putIfAbsent(k, () => v));
    }
    if (_reopen != null) {
      _reopen!.forEach((k, v) => body.putIfAbsent(k, () => v));
    }

    final uid = await deviceId();
    if (uid != null && uid.isNotEmpty) {
      body['af_id'] = uid;
    } else {
      body.putIfAbsent('af_id', () => '');
    }

    if (Platform.isIOS) {
      try {
        final status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.authorized) {
          final idfa =
              await AppTrackingTransparency.getAdvertisingIdentifier();
          if (idfa.isNotEmpty && !idfa.startsWith('00000000-')) {
            body.putIfAbsent('sub_id_10', () => idfa);
          }
        }
      } catch (_) {}
    }

    body['bundle_id'] = DungeonHubConfig.bundleId;
    body['store_id']  = DungeonHubConfig.platformStoreId;
    body['os']        = Platform.isAndroid ? 'Android' : 'iOS';
    body['locale']    = locale;
    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    if (DungeonHubConfig.firebaseNumber.isNotEmpty) {
      body['firebase_project_id'] = DungeonHubConfig.firebaseNumber;
    }

    hubLog(() => '[DGA.IT] payload keys=${body.keys.toList()}');
    return body;
  }
}
