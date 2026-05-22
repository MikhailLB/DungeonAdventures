import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';
import '../config/runtime_brand.dart';
import '../config/gateway_endpoints.dart';
import 'secure_http.dart';

class InstallSignalClient {
  AppsflyerSdk? _sdk;
  Map<String, dynamic>? _attributionData;
  Map<String, dynamic>? _deepLinkData;
  Map<String, dynamic>? _appOpenData;
  final Completer<Map<String, dynamic>> _attrCompleter = Completer();
  final Completer<void> _dlCompleter = Completer();
  bool _initialized = false;

  bool _looksLikeAttribution(Map<String, dynamic> p) =>
      p.containsKey('af_status') ||
      p.containsKey('media_source') ||
      p.containsKey('campaign') ||
      p.containsKey('is_first_launch') ||
      p.containsKey('install_time');

  Future<void> warmup() async {
    if (_initialized) return;
    _initialized = true;

    final options = AppsFlyerOptions(
      afDevKey: RuntimeBrand.installDevKey,
      appId: RuntimeBrand.analyticsAppId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    if (kDebugMode) {
      debugPrint('[Signal] init appId=${RuntimeBrand.analyticsAppId} '
          'pkg=${RuntimeBrand.packageName}');
    }

    _sdk = AppsflyerSdk(options);

    _sdk!.onInstallConversionData((data) async {
      final raw = Map<String, dynamic>.from(data);
      final payload =
          raw['payload'] != null ? Map<String, dynamic>.from(raw['payload'] as Map) : raw;

      if (!_looksLikeAttribution(payload)) {
        _attributionData = {};
        if (!_attrCompleter.isCompleted) _attrCompleter.complete({});
        return;
      }

      if (payload['af_status'] == 'Organic') {
        await Future.delayed(Duration(seconds: RuntimeBrand.syncRetrySeconds));
        final retry = await _fetchGcd();
        _attributionData = retry ?? payload;
      } else {
        _attributionData = payload;
      }

      if (!_attrCompleter.isCompleted) _attrCompleter.complete(_attributionData);
    });

    _sdk!.onAppOpenAttribution((data) {
      final raw = Map<String, dynamic>.from(data);
      _appOpenData = raw['payload'] != null
          ? Map<String, dynamic>.from(raw['payload'] as Map)
          : raw;
    });

    _sdk!.onDeepLinking((result) {
      if (result.deepLink != null) {
        final ev = Map<String, dynamic>.from(result.deepLink!.clickEvent);
        final dlv = result.deepLink!.deepLinkValue;
        if (dlv != null && dlv.isNotEmpty) ev['deep_link_value'] = dlv;
        ev['is_deferred'] = result.deepLink!.isDeferred ?? false;
        _deepLinkData = ev;
      }
      if (!_dlCompleter.isCompleted) _dlCompleter.complete();
    });

    await _sdk!.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
  }

  Future<Map<String, dynamic>?> _fetchGcd() async {
    try {
      final uid = await getUid();
      if (uid == null) return null;
      final appId = Platform.isIOS ? RuntimeBrand.analyticsAppId : RuntimeBrand.packageName;
      final uri = Uri.parse(
          '${GatewayEndpoints.gcdBaseUrl}${GatewayEndpoints.gcdPath}'
          '?app_id=$appId&device_id=$uid');
      final resp = await secureHttp.get(uri, headers: {
        'authorization': 'Bearer ${RuntimeBrand.installDevKey}',
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> waitForAttribution() =>
      _attrCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => {},
      );

  Future<void> waitForDeepLink() =>
      _dlCompleter.future.timeout(const Duration(seconds: 12), onTimeout: () {});

  Future<String?> getUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> composePayload({
    required String locale,
    String? pushToken,
  }) async {
    final body = <String, dynamic>{};

    if (_attributionData != null) body.addAll(_attributionData!);

    if (_deepLinkData != null) {
      for (final e in _deepLinkData!.entries) {
        body.putIfAbsent(e.key, () => e.value);
      }
    }

    if (_appOpenData != null) {
      for (final e in _appOpenData!.entries) {
        body.putIfAbsent(e.key, () => e.value);
      }
    }

    final uid = await getUid();
    body['af_id'] = uid?.isNotEmpty == true ? uid! : '';
    body['bundle_id'] = RuntimeBrand.packageName;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = RuntimeBrand.storeId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    if (RuntimeBrand.firebaseProject.isNotEmpty) {
      body['firebase_project_id'] = RuntimeBrand.firebaseProject;
    }

    if (kDebugMode) {
      debugPrint('[Signal] payload keys=${body.keys.toList()}');
    }

    return body;
  }
}
