import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bootstrap/loading_screen.dart';
import 'cartlock/game_assets.dart';
import 'cartlock/progress_store.dart';
import 'hub/infra/dungeon_vault.dart';
import 'hub/infra/hub_dispatch.dart';
import 'hub/infra/install_tracker.dart';
import 'hub/infra/net_probe.dart';
import 'hub/infra/signal_relay.dart';
import 'hub/pages/vault_splash.dart';
import 'screens/level_select_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/play_screen.dart';
import 'screens/skins_screen.dart';
import 'screens/ui_kit.dart';

/// Root application widget.
///
/// When [gateEnabled] is true the gray-hub flow runs first (VaultSplash).
/// Non-organic/returning users see the WebView; organic users land on the game
/// (MenuScreen). When false (pure white build) the game launches directly.
class DungeonAdventuresApp extends StatelessWidget {
  final DungeonVault vault;
  final NetProbe probe;
  final InstallTracker tracker;
  final HubDispatch dispatch;
  final SignalRelay relay;
  final bool gateEnabled;

  const DungeonAdventuresApp({
    super.key,
    required this.vault,
    required this.probe,
    required this.tracker,
    required this.dispatch,
    required this.relay,
    required this.gateEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chicken Way Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Dungeon.gold,
          secondary: Dungeon.green,
          surface: Dungeon.panel,
        ),
        scaffoldBackgroundColor: Dungeon.bg,
        useMaterial3: true,
      ),
      home: gateEnabled
          ? _GatedBootstrap(
              vault: vault,
              probe: probe,
              tracker: tracker,
              dispatch: dispatch,
              relay: relay,
            )
          : const _WhiteBootstrap(),
      routes: {
        // All white-part routes must be registered here so that navigation
        // from the gray flow never throws "Could not find route".
        '/menu': (ctx) => _menuOrLoadingFallback(ctx),
        '/level-select': (ctx) => _levelSelectFallback(ctx),
        '/skins': (ctx) => _skinsFallback(ctx),
      },
    );
  }

  static Widget _menuOrLoadingFallback(BuildContext ctx) =>
      const _WhiteBootstrap();
  static Widget _levelSelectFallback(BuildContext ctx) =>
      const _WhiteBootstrap();
  static Widget _skinsFallback(BuildContext ctx) => const _WhiteBootstrap();
}

// ── Gated path: VaultSplash routes to MenuScreen after game decision ─────────
class _GatedBootstrap extends StatelessWidget {
  final DungeonVault vault;
  final NetProbe probe;
  final InstallTracker tracker;
  final HubDispatch dispatch;
  final SignalRelay relay;

  const _GatedBootstrap({
    required this.vault,
    required this.probe,
    required this.tracker,
    required this.dispatch,
    required this.relay,
  });

  @override
  Widget build(BuildContext context) {
    return VaultSplash(
      vault: vault,
      probe: probe,
      tracker: tracker,
      dispatch: dispatch,
      relay: relay,
      // When the hub resolves to game: go directly to white part bootstrap.
      // VaultSplash already served as the loading experience — don't double it.
      onLaunchGame: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const _WhiteBootstrap()),
        );
      },
    );
  }
}

// ── White bootstrap: shows LoadingScreen while loading assets, then MenuScreen ─
class _WhiteBootstrap extends StatefulWidget {
  const _WhiteBootstrap();

  @override
  State<_WhiteBootstrap> createState() => _WhiteBootstrapState();
}

class _WhiteBootstrapState extends State<_WhiteBootstrap> {
  final GameAssets _assets = GameAssets();
  ProgressStore? _store;

  ProgressStore? _pendingStore;

  Future<void> _runBootstrap(ValueChanged<int> onStageChanged) async {
    // Allow all orientations during loading so the splash rotates freely.
    // Portrait lock happens in _onLoadingComplete, just before the game shows.

    onStageChanged(0);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    onStageChanged(1);
    await _assets.loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    onStageChanged(2);
    _pendingStore = await ProgressStore.create();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    onStageChanged(3);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Future<void> _onLoadingComplete() async {
    // Lock to portrait now that loading is done, then reveal the game.
    await SystemChrome.setPreferredOrientations(
        const [DeviceOrientation.portraitUp]);
    if (!mounted) return;
    setState(() => _store = _pendingStore);
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store == null) {
      return LoadingScreen(
        runBootstrap: _runBootstrap,
        onComplete: _onLoadingComplete,
      );
    }
    return MenuScreen(assets: _assets, store: store);
  }
}

// ── Route helpers that carry assets/store through named routes ────────────────
// These are only used if something navigates via named routes from the gray flow.
// The primary path goes through _WhiteBootstrap → MenuScreen directly.
Route<dynamic>? onGenerateRoute(
  RouteSettings settings,
  GameAssets assets,
  ProgressStore store,
) {
  switch (settings.name) {
    case '/menu':
      return MaterialPageRoute(
        builder: (_) => MenuScreen(assets: assets, store: store),
      );
    case '/level-select':
      return MaterialPageRoute(
        builder: (_) => LevelSelectScreen(assets: assets, store: store),
      );
    case '/skins':
      return MaterialPageRoute(
        builder: (_) => SkinsScreen(store: store),
      );
    case '/play':
      final args = settings.arguments as Map<String, dynamic>?;
      final levelId = args?['levelId'] as int? ?? 1;
      return MaterialPageRoute(
        builder: (_) => PlayScreen(
          assets: assets,
          store: store,
          startLevelId: levelId,
        ),
      );
    default:
      return null;
  }
}
