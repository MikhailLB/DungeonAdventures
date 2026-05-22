import 'dart:io';
import '../utils/byte_unmask.dart';
import 'gateway_endpoints.dart';

// Encoded with tool/encode_keys.dart — run it again to update.
// Seed: "dungeonad"

// AppsFlyer dev key for Android — HGNdz9XMHJpFih6eHdMDFL
const _installKeyAndroid = [
  154, 228, 238, 61, 100, 198, 148, 88, 98, 81, 200, 215, 159, 159, 82, 168,
  154, 199, 237, 29, 88, 179
];

// Firebase project number — 1030605698193
const _firebaseProjectAndroid = [
  227, 147, 147, 105, 40, 207, 249, 35, 19, 35, 137, 168, 197
];

class RuntimeBrand {
  static const String packageName = 'com.dungeonadventures.streetsurvive';
  static const String displayTitle = 'Dungeon Adventures';
  static const String iosAppId = '0000000000'; // iOS placeholder

  static const int notificationRetryDelaySeconds = 259200;
  static const int syncRetrySeconds = 2;

  static String get installDevKey => Platform.isIOS ? '' : um(_installKeyAndroid);

  static String get firebaseProject =>
      Platform.isIOS ? '' : um(_firebaseProjectAndroid);

  static String get analyticsAppId =>
      Platform.isIOS ? iosAppId : packageName;

  static String get storeId =>
      Platform.isIOS ? 'id$iosAppId' : packageName;

  static String get configUrl => GatewayEndpoints.configUrl;
  static String get privacyUrl => GatewayEndpoints.privacyUrl;
  static String get supportUrl => GatewayEndpoints.supportUrl;

  static bool get gateEnabled =>
      installDevKey.isNotEmpty && configUrl.isNotEmpty;
}
