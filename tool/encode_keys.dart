import 'dart:typed_data';

const _saltBytes = [0x64, 0x75, 0x6E, 0x67, 0x65, 0x6F, 0x6E, 0x61, 0x64];

Uint8List _buildKey() {
  final s = _saltBytes.fold<int>(0, (a, b) => (a * 31 + b) & 0xFFFFFFFF);
  final kb = Uint8List(16);
  var v = s;
  for (var i = 0; i < kb.length; i++) {
    v = (v * 1103515245 + 12345) & 0x7FFFFFFF;
    kb[i] = v & 0xFF;
  }
  return kb;
}

List<int> encode(String plaintext) {
  final key = _buildKey();
  final bytes = plaintext.codeUnits;
  return [for (var i = 0; i < bytes.length; i++) bytes[i] ^ key[i % key.length]];
}

String decode(List<int> data) {
  final key = _buildKey();
  final out = Uint8List(data.length);
  for (var i = 0; i < data.length; i++) {
    out[i] = data[i] ^ key[i % key.length];
  }
  return String.fromCharCodes(out);
}

void main() {
  final secrets = {
    'AF_KEY': 'HGNdz9XMHJpFih6eHdMDFL',
    'FIREBASE_PROJECT': '1030605698193',
    'GATEWAY_HOST': 'https://dunggeonadventures.com',
    'GATEWAY_PATH': '/config.php',
    'PRIVACY_URL': 'https://dunggeonadventures.com/privacy-policy.html',
    'SUPPORT_URL': 'https://dunggeonadventures.com/support.html',
    // User-Agent version fragments
    'CV_FRAG': '124.0.6367.82',      // Chrome version
    'WK_FRAG': '537.36',             // WebKit version
  };

  for (final entry in secrets.entries) {
    final enc = encode(entry.value);
    final dec = decode(enc);
    assert(dec == entry.value, 'Round-trip failed for ${entry.key}');
    // ignore: avoid_print
    print('${entry.key}: [${enc.join(', ')}]  // verify: $dec');
  }
}
