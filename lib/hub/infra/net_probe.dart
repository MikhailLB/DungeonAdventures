import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Connectivity checker that performs a real DNS lookup to avoid false
/// positives on captive portals.
class NetProbe {
  final Connectivity _conn = Connectivity();

  // Rotate through a couple of well-known hosts so the probe target is not a
  // single shared constant across builds.
  static const List<String> _hosts = ['www.apple.com', 'www.google.com'];

  Future<bool> isOnline() async {
    try {
      final results = await _conn.checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) return false;
    } catch (_) {
      return false;
    }
    for (final host in _hosts) {
      try {
        final lookup = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 4));
        if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
          return true;
        }
      } on SocketException {
        continue;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get onChange =>
      _conn.onConnectivityChanged;
}
