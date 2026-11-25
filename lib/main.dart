import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'admin.dart';
import 'screens.dart';
import 'welcome.dart';
import 'state.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) => FlutterError.presentError(d);
    ErrorWidget.builder = (d) => const Material(child: Center(child: Padding(padding: EdgeInsets.all(24), child: Text('مشکلی در نمایش این بخش پیش آمد. لطفاً به صفحه‌ی قبل برگردید.', textAlign: TextAlign.center))));
    final store = Store();
    await store.init();
    runApp(KashanEnergyApp(AppState(store)));
  }, (e, s) {});
}

class KashanEnergyApp extends StatefulWidget {
  final AppState s;
  const KashanEnergyApp(this.s, {super.key});
  @override
  State<KashanEnergyApp> createState() => _KashanEnergyAppState();
}

class _KashanEnergyAppState extends State<KashanEnergyApp> {
  bool splash = true;
  Timer? _st;
  @override
  void initState() {
    super.initState();
    _st = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => splash = false);
    });
  }

  @override
  void dispose() {
    _st?.cancel();
    super.dispose();
  }

  ThemeData _theme(Color seed, Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b).copyWith(secondary: const Color(0xFFF5C84C), error: const Color(0xFFE5484D)),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, scrolledUnderElevation: 0, elevation: 0),
        scaffoldBackgroundColor: Colors.transparent,
        pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()}),
      );

  @override
  Widget build(BuildContext context) => Scope(
        notifier: widget.s,
        child: Builder(builder: (c) {
          final a = Scope.of(c);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'انرژی کاشان',
            locale: const Locale('fa', 'IR'),
            supportedLocales: const [Locale('fa', 'IR')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: _theme(a.seed, Brightness.light),
            darkTheme: _theme(a.seed, Brightness.dark),
            themeMode: a.dark ? ThemeMode.dark : ThemeMode.light,
            builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(a.scale)), child: child!),
            home: splash ? WelcomeSplash(onDone: () => setState(() => splash = false)) : !a.onboarded ? const Onboarding() : !a.signedIn ? const AuthPage() : a.isAdmin ? const AdminShell() : const Shell(),
          );
        }),
      );
}
