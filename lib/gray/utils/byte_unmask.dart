import 'dart:typed_data';

// Seed: "dungeonad" — unique to this app so compiled byte arrays differ from sibling apps.
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

final _xk = _buildKey();

String um(List<int> data) {
  final out = Uint8List(data.length);
  for (var i = 0; i < data.length; i++) {
    out[i] = data[i] ^ _xk[i % _xk.length];
  }
  return String.fromCharCodes(out);
}
