import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'db.dart';
import 'screens/join_screen.dart';
import 'screens/shell_screen.dart';
import 'theme.dart';
import 'tracker.dart';
import 'updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = Db();
  final tracker = Tracker(db);
  await tracker.init();
  MapboxOptions.setAccessToken(const String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: 'pk.YOUR_MAPBOX_PUBLIC_TOKEN',
  ));

  runApp(
    MultiProvider(
      providers: [
        Provider<Db>.value(value: db),
        ChangeNotifierProvider<Tracker>.value(value: tracker),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
      ],
      child: const RallyApp(),
    ),
  );
}

class RallyApp extends StatefulWidget {
  const RallyApp({super.key});

  @override
  State<RallyApp> createState() => _RallyAppState();
}

class _RallyAppState extends State<RallyApp> {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navKey.currentContext;
      if (ctx != null) Updater.check(ctx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    return MaterialApp(
        navigatorKey: _navKey,
        title: 'RallyTrack',
        theme: AppTheme.light().copyWith(
          textTheme: GoogleFonts.manropeTextTheme(AppTheme.light().textTheme),
        ),
        darkTheme: AppTheme.dark().copyWith(
          textTheme: GoogleFonts.manropeTextTheme(AppTheme.dark().textTheme),
        ),
        themeMode: theme.isLight ? ThemeMode.light : ThemeMode.dark,
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snap) =>
              snap.hasData ? const ShellScreen() : const JoinScreen(),
        ),
      );
  }
}

