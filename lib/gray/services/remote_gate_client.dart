import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/runtime_brand.dart';
import '../models/gate_response.dart';
import '../services/runtime_cache.dart';
import 'secure_http.dart';

class RemoteGateClient {
  final RuntimeCache _cache;

  RemoteGateClient(this._cache);

  Future<GateResponse> dispatch(Map<String, dynamic> body) async {
    if (RuntimeBrand.configUrl.isEmpty) {
      return GateResponse.error('configUrl not set');
    }

    try {
      final uri = Uri.parse(RuntimeBrand.configUrl);
      if (kDebugMode) {
        debugPrint('[Gate] POST $uri');
        debugPrint('[Gate] body=${jsonEncode(body)}');
      }

      final response = await secureHttp
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 18));

      if (kDebugMode) {
        debugPrint('[Gate] status=${response.statusCode} body=${response.body}');
      }

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = GateResponse.fromJson(json);

        if (result.ok && result.url != null) {
          await _cache.setSavedUrl(result.url!);
          if (result.expires != null) {
            await _cache.setUrlExpires(result.expires!);
          }
        }

        return result;
      }
      return GateResponse.error('HTTP ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('[Gate] error: $e');
      return GateResponse.error(e.toString());
    }
  }
}
