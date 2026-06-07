import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bootstrap/loading_screen.dart';
import 'cartlock/game_assets.dart';
import 'cartlock/progress_store.dart';
import 'screens/menu_screen.dart';
import 'screens/ui_kit.dart';

class ChickenWayGoApp extends StatelessWidget {
  const ChickenWayGoApp({super.key});

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
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  final GameAssets _assets = GameAssets();
  ProgressStore? _store;
  ProgressStore? _pendingStore;

  Future<void> _runBootstrap(ValueChanged<int> onStageChanged) async {
    onStageChanged(0);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    onStageChanged(1);
    await _assets.loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    onStageChanged(2);
    _pendingStore = await ProgressStore.create();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    onStageChanged(3);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _onLoadingComplete() async {
    // Lock portrait just before showing the game.
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
