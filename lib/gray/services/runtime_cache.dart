import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/launch_route.dart';

class RuntimeCache {
  static const _keyRoute = 'gray_route';
  static const _keySavedUrl = 'g_sv_u';
  static const _keyUrlExpires = 'g_url_exp';
  static const _keyNotifSkipUntil = 'g_notif_skip';
  static const _keyNotifGranted = 'g_notif_granted';
  static const _keyNotifSysDenied = 'g_notif_sys_denied';
  static const _keyPushUrl = 'g_psh_u';

  late SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
  }

  LaunchRoute readRoute() =>
      LaunchRoute.fromString(_prefs.getString(_keyRoute));

  Future<void> writeRoute(LaunchRoute route) async =>
      _prefs.setString(_keyRoute, route.toStorageString());

  Future<String?> getSavedUrl() => _secure.read(key: _keySavedUrl);

  Future<void> setSavedUrl(String url) =>
      _secure.write(key: _keySavedUrl, value: url);

  int? getUrlExpires() => _prefs.getInt(_keyUrlExpires);

  Future<void> setUrlExpires(int ts) => _prefs.setInt(_keyUrlExpires, ts);

  bool isUrlExpired() {
    final exp = getUrlExpires();
    if (exp == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
  }

  bool isNotifGranted() => _prefs.getBool(_keyNotifGranted) ?? false;

  Future<void> setNotifGranted(bool v) => _prefs.setBool(_keyNotifGranted, v);

  bool isNotifSysDenied() => _prefs.getBool(_keyNotifSysDenied) ?? false;

  Future<void> setNotifSysDenied(bool v) =>
      _prefs.setBool(_keyNotifSysDenied, v);

  int? getNotifSkipUntil() => _prefs.getInt(_keyNotifSkipUntil);

  Future<void> setNotifSkipUntil(int ts) =>
      _prefs.setInt(_keyNotifSkipUntil, ts);

  bool shouldShowNotifScreen() {
    if (isNotifSysDenied()) return false;
    if (isNotifGranted()) return false;
    final skip = getNotifSkipUntil();
    if (skip == null) return true;
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= skip;
  }

  Future<String?> getOneShotPush() => _secure.read(key: _keyPushUrl);

  Future<void> stashOneShotPush(String url) =>
      _secure.write(key: _keyPushUrl, value: url);

  Future<String?> consumeOneShotPush() async {
    final url = await getOneShotPush();
    if (url != null) await _secure.delete(key: _keyPushUrl);
    return url;
  }
}
