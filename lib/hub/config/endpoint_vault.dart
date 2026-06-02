import '../../helpers/cipher.dart';

String hubEndpointUrl() => '';

const List<int> _gcdMask = [21, 71, 59, 13, 37, 182, 213, 126, 180, 215, 116, 143, 18, 133, 43, 126, 187, 232, 76, 79, 243, 199, 1, 163, 97, 102, 149, 76, 93, 253, 251, 246, 88, 167, 223, 158, 167, 119, 154, 221, 137, 111, 4, 42, 179, 38, 86];

String hubGcdUrl(String appId, String deviceId) {
  final host = unmask(_gcdMask);
  if (host.isEmpty) return '';
  final sep = host.contains('?') ? '&' : '?';
  return '$host${sep}app_id=$appId&device_id=$deviceId';
}

String uaChromeBuild() => '131.0.6778.135';
String uaSafariBuild() => '605.1.15';
