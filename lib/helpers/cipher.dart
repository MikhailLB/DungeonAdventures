import 'dart:typed_data';

/// String obfuscation for secrets stored as byte arrays.
///
/// This app uses an RC4-style stream cipher (KSA + PRGA over a 256-byte
/// permutation). The algorithm is intentionally different from sibling
/// projects so the compiled decode routine is not byte-identical across the
/// portfolio. Seed below is unique to DungeonAdventures.
// "dga.keep.v2"
const _seed = <int>[
  0x64, 0x67, 0x61, 0x2E, 0x6B, 0x65, 0x65, 0x70, 0x2E, 0x76, 0x32,
];

Uint8List _keystream(int n) {
  // KSA — build the permutation from the seed.
  final s = List<int>.generate(256, (i) => i);
  var j = 0;
  for (var i = 0; i < 256; i++) {
    j = (j + s[i] + _seed[i % _seed.length]) & 0xFF;
    final t = s[i];
    s[i] = s[j];
    s[j] = t;
  }
  // PRGA — emit n keystream bytes.
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

/// Decode an obfuscated byte list back to its plaintext string.
/// Use `tool/encode_creds.dart` to produce byte arrays for new values.
String unmask(List<int> raw) {
  if (raw.isEmpty) return '';
  final ks = _keystream(raw.length);
  final out = Uint8List(raw.length);
  for (var i = 0; i < raw.length; i++) {
    out[i] = raw[i] ^ ks[i];
  }
  return String.fromCharCodes(out);
}
