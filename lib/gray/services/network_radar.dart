import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkRadar {
  final Connectivity _connectivity = Connectivity();

  Future<bool> hasInternet() async {
    final results = await _connectivity.checkConnectivity();
    if (!results.any((r) => r != ConnectivityResult.none)) return false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<List<ConnectivityResult>> get onChange =>
      _connectivity.onConnectivityChanged;
}
