import 'dart:typed_data';

/// XOR-based string obfuscation for secrets stored as byte arrays.
/// Seed is unique to DungeonAdventures — differs from every sibling project
/// so byte arrays are not interchangeable across apps.
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

/// Decode an XOR-encoded byte list back to its plaintext string.
/// Use `tool/encode_creds.dart` to produce byte arrays for new values.
String unmask(List<int> raw) {
  if (raw.isEmpty) return '';
  final sn = _stream.length;
  final out = Uint8List(raw.length);
  for (var i = 0; i < raw.length; i++) {
    out[i] = raw[i] ^ _stream[i % sn];
  }
  return String.fromCharCodes(out);
}
