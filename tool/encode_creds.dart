// ignore_for_file: avoid_print
// Run with: dart run tool/encode_creds.dart
// Copy the printed byte arrays into lib/hub/config/.
// MUST stay in sync with lib/helpers/cipher.dart (same algorithm + seed).
import 'dart:typed_data';

// "dga.keep.v2"
const _seed = <int>[
  0x64, 0x67, 0x61, 0x2E, 0x6B, 0x65, 0x65, 0x70, 0x2E, 0x76, 0x32,
];

Uint8List _keystream(int n) {
  final s = List<int>.generate(256, (i) => i);
  var j = 0;
  for (var i = 0; i < 256; i++) {
    j = (j + s[i] + _seed[i % _seed.length]) & 0xFF;
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
  }
  final out = Uint8List(n);
  var a = 0, b = 0;
  for (var k = 0; k < n; k++) {
    a = (a + 1) & 0xFF;
    b = (b + s[a]) & 0xFF;
    final t = s[a];
    s[a] = s[b];
    s[b] = t;
    out[k] = s[(s[a] + s[b]) & 0xFF];
  }
  return out;
}

List<int> encode(String str) {
  final ks = _keystream(str.length);
  final out = <int>[];
  for (var i = 0; i < str.length; i++) {
    out.add(str.codeUnitAt(i) ^ ks[i]);
  }
  return out;
}

String unmask(List<int> raw) {
  final ks = _keystream(raw.length);
  final out = Uint8List(raw.length);
  for (var i = 0; i < raw.length; i++) {
    out[i] = raw[i] ^ ks[i];
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

  final hostV = encode(configHost);
  final pathV = encode(configPath);
  final privV = encode(privacyUrl);
  final suppV = encode(supportUrl);
  final gcdV  = encode(gcdHost);
  final afV   = encode(afKey);
  final fbV   = encode(firebaseNum);

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
