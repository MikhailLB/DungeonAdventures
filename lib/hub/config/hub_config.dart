import 'dart:io';
import 'endpoint_vault.dart';
import 'signal_keys.dart';
import 'brand_links.dart';

/// Central constants for the DungeonAdventures gray hub layer.
abstract final class DungeonHubConfig {
  // ── iOS App Store numeric ID ──────────────────────────────
  static const String iosStoreId = '6770978783';

  // ── Bundle / package ID ───────────────────────────────────
  static const String bundleId = 'com.farmyard.chickenwaygo';

  // ── Display name used in debug logs ──────────────────────
  static const String appTitle = 'Chicken Way Go';

  // ── Timing constants ─────────────────────────────────────
  /// Seconds before push opt-in re-appears after Skip.
  static const int pushCooldownSeconds = 259200; // 3 days

  /// Seconds to retry GCD when AppsFlyer reports Organic.
  static const int organicRetrySeconds = 6;

  /// Hard boot timeout: falls back to game after this many seconds.
  static const int bootBudgetSeconds = 20;

  // ── Derived ──────────────────────────────────────────────
  static String get configEndpoint     => hubEndpointUrl();
  static String get installKey         => dgaAppsflyerKey();
  static String get firebaseNumber     => dgaFirebaseNumber();
  static String get privacyUrl         => dungeonPrivacyUrl;
  static String get supportUrl         => dungeonSupportUrl;
  static String get platformStoreId    =>
      Platform.isIOS ? 'id$iosStoreId' : bundleId;
  static String get analyticsAppId     =>
      Platform.isIOS ? iosStoreId : bundleId;
}
