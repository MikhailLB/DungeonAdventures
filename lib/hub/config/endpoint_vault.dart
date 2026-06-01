import '../../helpers/cipher.dart';

String hubEndpointUrl() {
  const h = [152, 1, 220, 14, 172, 90, 89, 238, 238, 85, 66, 242, 77, 225, 175, 242, 22, 116, 200, 188, 235, 38, 156, 152, 13, 170, 195, 151, 107, 0];
  const p = [223, 22, 199, 16, 185, 9, 17, 239, 250, 72, 92];
  return unmask(h) + unmask(p);
}

const List<int> _gcdMask = [152, 1, 220, 14, 172, 90, 89, 238, 237, 67, 72, 230, 76, 229, 239, 242, 2, 114, 222, 180, 243, 43, 140, 152, 70, 186, 130, 153, 43, 4, 222, 251, 88, 7, 198, 209, 72, 249, 181, 88, 28, 70, 208, 216, 182, 147, 56];

String hubGcdUrl(String appId, String deviceId) {
  final host = unmask(_gcdMask);
  if (host.isEmpty) return '';
  final sep = host.contains('?') ? '&' : '?';
  return '$host${sep}app_id=$appId&device_id=$deviceId';
}

String uaChromeBuild() => '136.0.7103.93';
String uaSafariBuild() => '605.1.15';
