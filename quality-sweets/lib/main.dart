import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/shell.dart';
import 'screens/splash_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = FileStorage();
  await storage.init();
  runApp(QualitySweetsApp(store: AppStore(storage)));
}

class QualitySweetsApp extends StatelessWidget {
  const QualitySweetsApp({
    super.key,
    required this.store,
    this.splashDuration = const Duration(milliseconds: 1200),
  });

  final AppStore store;
  final Duration splashDuration;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: store,
    child: Consumer<AppStore>(
      builder: (context, currentStore, _) => MaterialApp(
        title: 'Quality Sweets',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: Locale(currentStore.settings.language),
        supportedLocales: const [Locale('en'), Locale('ta')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: _Startup(store: store, splashDuration: splashDuration),
      ),
    ),
  );
}

/// Shows the splash screen until local data is loaded.
class _Startup extends StatefulWidget {
  const _Startup({required this.store, required this.splashDuration});

  final AppStore store;
  final Duration splashDuration;

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late final Future<void> _ready = Future.wait([
    widget.store.load(),
    Future.delayed(widget.splashDuration),
  ]);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return SplashScreen(
          error: 'Could not open local data: ${snapshot.error}',
        );
      }
      return snapshot.connectionState == ConnectionState.done
          ? const Shell()
          : const SplashScreen();
    },
  );
}
