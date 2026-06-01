import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'hub_log.dart';

/// Reads the cold-start push URL that SceneDelegate captured before Dart was
/// alive.
///
/// SceneDelegate writes the URL to UserDefaults under `flutter.dga_cold_tap_url`.
/// The `flutter.` prefix is required: SharedPreferences on iOS namespaces every
/// key with it, so reading via SharedPreferences matches UserDefaults.
class ColdTapReader {
  static const String _key = 'dga_cold_tap_url';

  /// Returns and clears the URL left by SceneDelegate on a cold-start push tap.
  /// Returns null on non-iOS or when nothing is stored.
  static Future<String?> consumeTapUrl() async {
    if (!Platform.isIOS) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.trim().isEmpty) {
        hubLog(() => '[DGA.CTR] consumeTapUrl -> null');
        return null;
      }
      await prefs.remove(_key);
      hubLog(() => '[DGA.CTR] consumeTapUrl -> "$raw"');
      return raw.trim();
    } catch (err) {
      hubLog(() => '[DGA.CTR] consumeTapUrl failed: $err');
      return null;
    }
  }
}
