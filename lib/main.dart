import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'gray/gray_boot.dart';

Future<void> main() async {
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

  final gray = await GrayBoot.prepare();

  runApp(MaterialApp(
    title: 'Dungeon Adventures',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFC853),
        secondary: Color(0xFF66BB6A),
        surface: Color(0xFF0F111A),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0B10),
    ),
    home: gray.buildHome(
      fallbackHomeBuilder: (_) => const DungeonBootstrap(),
    ),
  ));
}
