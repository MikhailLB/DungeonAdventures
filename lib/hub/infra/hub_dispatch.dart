import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/hub_config.dart';
import '../models/hub_reply.dart';
import 'masked_agent.dart';
import 'dungeon_vault.dart';

/// Posts an install/launch payload to the remote hub endpoint and caches the
/// returned destination URL.
class HubDispatch {
  final DungeonVault _vault;

  HubDispatch(this._vault);

  Future<HubReply> send(Map<String, dynamic> body) async {
    final endpoint = DungeonHubConfig.configEndpoint;
    debugPrint('[DGA.HD] send → endpoint="$endpoint"');
    if (endpoint.isEmpty) {
      debugPrint('[DGA.HD] endpoint not configured — declined');
      return HubReply.declined('endpoint_missing');
    }
    try {
      final uri = Uri.parse(endpoint);
      debugPrint('[DGA.HD] POST $uri  body=${jsonEncode(body)}');
      final resp = await maskedAgent
          .post(uri,
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));

      debugPrint('[DGA.HD] HTTP ${resp.statusCode}');
      final preview = resp.body.length > 500
          ? '${resp.body.substring(0, 500)}…'
          : resp.body;
      debugPrint('[DGA.HD] body=$preview');

      if (resp.statusCode != 200) {
        return HubReply.declined('http_${resp.statusCode}');
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        return HubReply.declined('bad_json');
      }
      final reply = HubReply.fromMap(decoded);
      debugPrint(
          '[DGA.HD] reply granted=${reply.granted} dest=${reply.destination}');
      if (reply.granted && reply.destination != null) {
        await _vault.writeSavedUrl(reply.destination!);
        if (reply.expiresAt != null) {
          await _vault.writeSavedTtl(reply.expiresAt!);
        }
      }
      return reply;
    } catch (err, st) {
      debugPrint('[DGA.HD] error: $err\n$st');
      return HubReply.declined(err.toString());
    }
  }
}
