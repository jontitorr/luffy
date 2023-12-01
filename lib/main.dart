import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_displaymode/flutter_displaymode.dart";
import "package:luffy/api/user_settings.dart";
import "package:luffy/auth.dart";
import "package:luffy/screens/home.dart";
import "package:luffy/screens/login.dart";
import "package:luffy/screens/welcome.dart";
import "package:luffy/scroll_behavior.dart";
import "package:luffy/theme.dart";
import "package:luffy/util.dart";
import "package:media_kit/media_kit.dart";
import "package:window_manager/window_manager.dart";

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await windowManager.ensureInitialized();
  }

  if (!kIsWeb &&
      kDebugMode &&
      defaultTargetPlatform == TargetPlatform.android) {
    // await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await FlutterDisplayMode.setHighRefreshRate();
  }

  // runApp(const MyApp());

  // final animes = await Kaido.search("one piece");
  // final episodes = await Kaido.loadEpisodes(animes[0], {});

  // prints("episodes: $episodes");

  // final skips = await AniSkip.getSkips(21, 2);
  // prints("skips: $skips");

  // final animes = await KickassAnime().search("one piece");
  // final episodes = await KickassAnime().getEpisodes(animes[1]);
  // final sources = await KickassAnime().getSources(episodes[0]);
  // prints("sources: $sources");
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
    final settings = _settings;

    if (settings == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return MaterialApp(
      title: "Luffy",
      theme: lightTheme(primaryColor: settings.lightThemeColor),
      darkTheme: darkTheme(primaryColor: settings.darkThemeColor),
      home: settings.welcomeScreenShown
          ? const HomeScreen()
          : const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
      scrollBehavior: CustomScrollBehavior(),
      routes: {
        "/home": (context) => const HomeScreen(),
        "/login": (context) => const LoginScreen(),
      },
    );
  }
}
