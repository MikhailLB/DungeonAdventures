import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import '../utils/byte_unmask.dart';

// Chrome version: 124.0.6367.82 / WebKit: 537.36
// Encoded with tool/encode_keys.dart (seed: "dungeonad")
String get _cvFrag => um(const [
      227, 145, 148, 119, 46, 209, 250, 38, 28, 44, 150, 169, 196
    ]);
String get _wkFrag => um(const [231, 144, 151, 119, 45, 201]);

class SecureHttp extends http.BaseClient {
  final http.Client _inner = http.Client();
  String? _ua;

  Future<void> warmup() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        _ua = 'Mozilla/5.0 (Linux; Android ${a.version.sdkInt}; '
            '${a.brand} ${a.model} Build/${a.display.isNotEmpty ? a.display : a.id}) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/$_cvFrag Mobile Safari/537.36';
      } else {
        final i = await info.iosInfo;
        final ver = i.systemVersion.replaceAll('.', '_');
        _ua = 'Mozilla/5.0 (iPhone; CPU iPhone OS $ver like Mac OS X) '
            'AppleWebKit/$_wkFrag (KHTML, like Gecko) '
            'Version/${i.systemVersion} Mobile/15E148 Safari/$_wkFrag';
      }
    } catch (_) {
      _ua = Platform.isAndroid
          ? 'Mozilla/5.0 (Linux; Android 14; Pixel 9) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/$_cvFrag Mobile Safari/537.36'
          : 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) '
              'AppleWebKit/$_wkFrag (KHTML, like Gecko) '
              'Version/17.4 Mobile/15E148 Safari/$_wkFrag';
    }
  }

  String get userAgent => _ua ?? 'Mozilla/5.0';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent('User-Agent', () => userAgent);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

final secureHttp = SecureHttp();
