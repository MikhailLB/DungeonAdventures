// ignore_for_file: avoid_print
// Run with: dart run tool/encode_creds.dart
// Copy the printed byte arrays into lib/hub/config/
import 'dart:typed_data';

// DungeonAdventures-specific seed — different from every other project.
// "dga.hub.key1"
const _seedBytes = <int>[
  0x64, 0x67, 0x61, 0x2E, 0x68, 0x75, 0x62, 0x2E,
  0x6B, 0x65, 0x79, 0x31,
];

Uint8List _deriveKeyStream(int size) {
  var hash = 0x811C9DC5;
  for (final b in _seedBytes) {
    hash = ((hash ^ b) * 0x01000193) & 0xFFFFFFFF;
  }
  final out = Uint8List(size);
  var state = hash == 0 ? 0xDEADBEEF : hash;
  for (var i = 0; i < size; i++) {
    state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
    out[i] = (state >> 7) & 0xFF;
  }
  return out;
}

final _stream = _deriveKeyStream(128);

List<int> encode(String s) {
  final out = <int>[];
  for (var i = 0; i < s.length; i++) {
    out.add(s.codeUnitAt(i) ^ _stream[i % _stream.length]);
  }
  return out;
}

String unmask(List<int> raw) {
  final out = Uint8List(raw.length);
  for (var i = 0; i < raw.length; i++) {
    out[i] = raw[i] ^ _stream[i % _stream.length];
  }
  return String.fromCharCodes(out);
}

String fmt(List<int> v) => '[${v.join(', ')}]';

void main() {
  const configHost  = 'https://dungeonadventtures.com';
  const configPath  = '/config.php';
  const privacyUrl  = 'https://dungeonadventtures.com/privacy-policy.html';
  const supportUrl  = 'https://dungeonadventtures.com/support.html';
  const gcdHost     = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';
  const afKey       = 'HALyK8KJBwMG7oJNhnsKUH';
  const firebaseNum = '188313373870';

  final hostV    = encode(configHost);
  final pathV    = encode(configPath);
  final privV    = encode(privacyUrl);
  final suppV    = encode(supportUrl);
  final gcdV     = encode(gcdHost);
  final afV      = encode(afKey);
  final fbV      = encode(firebaseNum);

  print('// ── endpoint_vault.dart ──────────────────────────');
  print('const _hostMask = ${fmt(hostV)};');
  print('const _pathMask = ${fmt(pathV)};');
  print('const _gcdMask  = ${fmt(gcdV)};');
  print('');
  print('// ── signal_keys.dart ────────────────────────────');
  print('const _afKeyMask = ${fmt(afV)};');
  print('const _fbNumMask = ${fmt(fbV)};');
  print('');
  print('// ── brand_links.dart ────────────────────────────');
  print('const _privacyMask = ${fmt(privV)};');
  print('const _supportMask = ${fmt(suppV)};');

  print('\n// ── VERIFY ──────────────────────────────────────');
  print('HOST     : ${unmask(hostV)}');
  print('PATH     : ${unmask(pathV)}');
  print('PRIVACY  : ${unmask(privV)}');
  print('SUPPORT  : ${unmask(suppV)}');
  print('GCD      : ${unmask(gcdV)}');
  print('AF_KEY   : ${unmask(afV)}');
  print('FB_NUM   : ${unmask(fbV)}');
}
