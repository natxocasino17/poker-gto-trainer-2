import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'data/repositories/game_repository.dart';
import 'presentation/providers/game_provider.dart';
import 'presentation/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF141414),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final repo = await GameRepository.create();

  runApp(
    ChangeNotifierProvider(
      create: (_) => GameProvider(repo)..initialize(),
      child: const PokerGTOApp(),
    ),
  );
}

class PokerGTOApp extends StatelessWidget {
  const PokerGTOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iPT - iPoker Training',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const MainScaffold(),
    );
  }
}
