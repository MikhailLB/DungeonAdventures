import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'hub/config/endpoint_vault.dart';
import 'hub/config/signal_keys.dart';
import 'hub/infra/dungeon_vault.dart';
import 'hub/infra/hub_dispatch.dart';
import 'hub/infra/install_tracker.dart';
import 'hub/infra/masked_agent.dart';
import 'hub/infra/net_probe.dart';
import 'hub/infra/signal_relay.dart';
import 'hub/infra/hub_log.dart';

Future<void> _bootFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (err) {
    hubLog(() => '[BOOT] Firebase init skipped: $err');
    return;
  }
  try {
    await FirebaseAppCheck.instance.activate(
      // ignore: deprecated_member_use
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      // ignore: deprecated_member_use
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.appAttestWithDeviceCheckFallback,
    );
  } catch (err) {
    hubLog(() => '[BOOT] AppCheck skipped: $err');
  }
}

Future<void> main() async {
  final sw = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Firebase + UA warmup + vault — run in parallel for speed.
  final firebaseFuture = _bootFirebase();
  final agentFuture    = maskedAgent.warmup();
  final vault          = DungeonVault();
  final vaultFuture    = vault.init().catchError((err) {
    hubLog(() => '[BOOT] vault init failed: $err');
  });

  await firebaseFuture;
  hubLog(() => '[BOOT] firebase ready ${sw.elapsedMilliseconds}ms');
  await Future.wait([agentFuture, vaultFuture]);
  hubLog(() => '[BOOT] agent+vault ready ${sw.elapsedMilliseconds}ms');

  final probe    = NetProbe();
  final tracker  = InstallTracker();
  final dispatch = HubDispatch(vault);
  final relay    = SignalRelay(vault);

  // Pre-fire push bootstrap in parallel with first frame render.
  unawaited(relay.bootstrap().catchError((err) {
    hubLog(() => '[BOOT] relay pre-fire: $err');
  }));

  final gateEnabled =
      hubEndpointUrl().isNotEmpty || dgaAppsflyerKey().isNotEmpty;

  hubLog(() => '[BOOT] gateEnabled=$gateEnabled  ${sw.elapsedMilliseconds}ms');

  runApp(DungeonAdventuresApp(
    vault: vault,
    probe: probe,
    tracker: tracker,
    dispatch: dispatch,
    relay: relay,
    gateEnabled: gateEnabled,
  ));
}
