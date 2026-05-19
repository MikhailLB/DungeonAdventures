import '../utils/byte_unmask.dart';

// All secrets encoded with tool/encode_keys.dart (seed: "dungeonad")

const _gateHostMask = [
  186, 215, 212, 41, 109, 197, 227, 58, 78, 110, 214, 246, 145, 146, 11, 163,
  179, 199, 214, 60, 112, 139, 185, 103, 79, 104, 150, 242, 153, 154
];
const _gatePathMask = [253, 192, 207, 55, 120, 150, 171, 59, 90, 115, 200];

const _privacyMask = [
  186, 215, 212, 41, 109, 197, 227, 58, 78, 110, 214, 246, 145, 146, 11, 163,
  179, 199, 214, 60, 112, 139, 185, 103, 79, 104, 150, 242, 153, 154, 75, 189,
  160, 202, 214, 56, 125, 134, 225, 101, 69, 119, 209, 242, 143, 217, 12, 185,
  191, 207
];
const _supportMask = [
  186, 215, 212, 41, 109, 197, 227, 58, 78, 110, 214, 246, 145, 146, 11, 163,
  179, 199, 214, 60, 112, 139, 185, 103, 79, 104, 150, 242, 153, 154, 75, 190,
  167, 211, 208, 54, 108, 139, 226, 125, 94, 118, 212
];

// AppsFlyer GCD (Get Conversion Data) fallback endpoint
const _gcdHostMask = [
  186, 215, 212, 41, 109, 197, 227, 58, 75, 107, 200, 226, 144, 155, 29, 168,
  160, 142, 211, 50, 127, 155, 162, 112, 94, 108, 215, 227, 157, 217, 7, 162,
  191
];
const _gcdPathMask = [253, 194, 208, 48, 49, 137, 248, 58, 77, 120, 220];

class GatewayEndpoints {
  static String get configUrl => um(_gateHostMask) + um(_gatePathMask);
  static String get privacyUrl => um(_privacyMask);
  static String get supportUrl => um(_supportMask);
  static String get gcdBaseUrl => um(_gcdHostMask);
  static String get gcdPath => um(_gcdPathMask);
}
