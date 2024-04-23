import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_displaymode/flutter_displaymode.dart";
import "package:luffy/api/user_settings.dart";
import "package:luffy/auth.dart";
import "package:luffy/components/loading.dart";
import "package:luffy/screens/home.dart";
import "package:luffy/screens/login.dart";
import "package:luffy/screens/welcome.dart";
import "package:luffy/scroll_behavior.dart";
import "package:luffy/theme.dart";
import "package:luffy/util.dart";
import "package:media_kit/media_kit.dart";
import "package:responsive_framework/responsive_framework.dart";
import "package:window_manager/window_manager.dart";

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await windowManager.ensureInitialized();
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await FlutterDisplayMode.setHighRefreshRate();
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  // ignore: library_private_types_in_public_api
  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {
  MalToken? _token;
  UserSettings? _settings;

  void changeThemeColor(Color color) {
    // TODO(xminent): Maybe add more customization in terms of being able to
    // use light themes, despite being in a system dark theme.
    _changeLightThemeColor(color);
    _changeDarkThemeColor(color);
  }

  void _changeDarkThemeColor(Color color) {
    setState(() {
      if (_settings?.darkThemeColor == color) {
        prints("Same color");
        return;
      }

      _settings?.changeDarkThemeColor(color);
    });
  }

  void _changeLightThemeColor(Color color) {
    setState(() {
      if (_settings?.lightThemeColor == color) {
        prints("Same color");
        return;
      }

      _settings?.changeLightThemeColor(color);
    });
  }

  void setToken(MalToken? token) {
    setState(() {
      final oldToken = _token;
      _token = token;
      prints("Token set to: $token | Was: $oldToken");

      if (oldToken != _token) {
        void rebuild(Element el) {
          el.markNeedsBuild();
          el.visitChildren(rebuild);
        }

        (context as Element).visitChildren(rebuild);
      }
    });
  }

  MalToken? get malToken => _token;

  @override
  void initState() {
    super.initState();

    MalToken.getInstance().then((token) {
      setState(() {
        _token = token;
      });
    });

    UserSettings.getInstance().then((settings) {
      setState(() {
        _settings = settings;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([MalToken.getInstance(), UserSettings.getInstance()]),
      builder: (context, snapshot) {
        // If still waiting show loading indicator.
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingIndicator();
        }

        final token = snapshot.data![0] as MalToken?;
        final settings = snapshot.data![1]! as UserSettings;

        return MaterialApp(
          title: "Luffy",
          theme: lightTheme(primaryColor: settings.lightThemeColor),
          darkTheme: darkTheme(primaryColor: settings.darkThemeColor),
          home: settings.welcomeScreenShown && token != null
              ? const HomeScreen()
              : const WelcomeScreen(),
          debugShowCheckedModeBanner: false,
          scrollBehavior: CustomScrollBehavior(),
          routes: {
            "/home": (context) => const HomeScreen(),
            "/login": (context) => const LoginScreen(),
          },
          builder: (context, child) => ResponsiveBreakpoints.builder(
            child: child!,
            breakpoints: [
              const Breakpoint(start: 0, end: 450, name: MOBILE),
              const Breakpoint(start: 451, end: 800, name: TABLET),
              const Breakpoint(start: 801, end: 1920, name: DESKTOP),
              const Breakpoint(start: 1921, end: double.infinity, name: "4K"),
            ],
          ),
        );
      },
    );
  }
}
