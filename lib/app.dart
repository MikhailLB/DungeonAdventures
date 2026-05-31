import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'bootstrap/loading_screen.dart';
import 'cartlock/game_assets.dart';
import 'cartlock/progress_store.dart';
import 'screens/menu_screen.dart';
import 'screens/ui_kit.dart';

class DungeonAdventuresApp extends StatelessWidget {
  const DungeonAdventuresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dungeon Adventures',
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
      home: const _BootstrapFlow(),
    );
  }
}

class _BootstrapFlow extends StatefulWidget {
  const _BootstrapFlow();

  @override
  State<_BootstrapFlow> createState() => _BootstrapFlowState();
}

class _BootstrapFlowState extends State<_BootstrapFlow> {
  final GameAssets _assets = GameAssets();
  ProgressStore? _store;
  bool _ready = false;

  Future<void> _bootstrap(ValueChanged<int> onStageChanged) async {
    onStageChanged(0);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    onStageChanged(1);
    await _assets.loadAll();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    onStageChanged(2);
    _store = await ProgressStore.create();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    onStageChanged(3);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _onLoadingComplete() async {
    await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
    if (!mounted) {
      return;
    }
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _store == null) {
      return LoadingScreen(
        runBootstrap: _bootstrap,
        onComplete: _onLoadingComplete,
      );
    }

    return MenuScreen(assets: _assets, store: _store!);
  }
}
