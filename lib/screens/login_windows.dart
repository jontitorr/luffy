import "dart:async";
import "dart:convert";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:http/http.dart" as http;
import "package:luffy/auth.dart";
import "package:luffy/main.dart";
import "package:webview_windows/webview_windows.dart";

const malRedirectUri = "https://localhost/authorize";

final navigatorKey = GlobalKey<NavigatorState>();

String _generateCodeVerifier() {
  const unreservedChars =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~";
  final random = Random.secure();
  final codeVerifier = List.generate(
    128,
    (_) => unreservedChars[random.nextInt(unreservedChars.length)],
  );
  final codeVerifierString =
      String.fromCharCodes(codeVerifier.map((s) => s.codeUnitAt(0)).toList());
  final base64UrlEncoded = base64Url.encode(utf8.encode(codeVerifierString));
  return base64UrlEncoded.substring(0, 128);
}

class OauthVars {
  OauthVars({
    required this.codeVerifier,
    required this.state,
    required this.loginUrl,
  });

  final String codeVerifier;
  final String state;
  final String loginUrl;
}

class LoginWindowsScreen extends StatefulWidget {
  const LoginWindowsScreen({super.key});

  @override
  State<LoginWindowsScreen> createState() => LoginWindowsScreenState();
}

class LoginWindowsScreenState extends State<LoginWindowsScreen> {
  final _controller = WebviewController();
  final _textController = TextEditingController();
  final List<StreamSubscription> _subscriptions = [];
  bool _isWebviewSuspended = false;
  late Future<OauthVars> _oauthVars;

  @override
  void initState() {
    super.initState();
    _oauthVars = setupOauthVars();
    initPlatformState();
  }

  Future<OauthVars> setupOauthVars() async {
    final codeChallenge = _generateCodeVerifier();
    const state = "luffy";

    final loginUrl =
        "https://myanimelist.net/v1/oauth2/authorize?response_type=code&client_id=$malClientId&code_challenge=$codeChallenge&code_challenge_method=plain&state=$state&redirect_uri=$malRedirectUri";

    return OauthVars(
      codeVerifier: codeChallenge,
      state: state,
      loginUrl: loginUrl,
    );
  }

  Future<void> initPlatformState() async {
    try {
      await _controller.initialize();

      _subscriptions.add(
        _controller.url.listen((url) async {
          _textController.text = url;

          handleNavigationStateChange(await _oauthVars, Uri.parse(url));
        }),
      );

      await _controller.setBackgroundColor(Colors.transparent);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.loadUrl((await _oauthVars).loginUrl);

      if (!mounted) {
        return;
      }

      setState(() {});
    } on PlatformException catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Error"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Code: ${e.code}"),
                Text("Message: ${e.message}"),
              ],
            ),
            actions: [
              TextButton(
                child: const Text("Continue"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      });
    }
  }

  Widget compositeView() {
    if (!_controller.value.isInitialized) {
      return const Text(
        "Not Initialized",
        style: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            elevation: 0,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "URL",
                      contentPadding: EdgeInsets.all(10.0),
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    controller: _textController,
                    onSubmitted: (val) {
                      _controller.loadUrl(val);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  splashRadius: 20,
                  onPressed: () {
                    _controller.reload();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.developer_mode),
                  tooltip: "Open DevTools",
                  splashRadius: 20,
                  onPressed: () {
                    _controller.openDevTools();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Card(
              color: Colors.transparent,
              elevation: 0,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Stack(
                children: [
                  Webview(
                    _controller,
                    permissionRequested: _onPermissionRequested,
                  ),
                  StreamBuilder<LoadingState>(
                    stream: _controller.loadingState,
                    builder: (context, snapshot) {
                      if (snapshot.hasData &&
                          snapshot.data == LoadingState.loading) {
                        return const LinearProgressIndicator();
                      } else {
                        return const SizedBox();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> handleNavigationStateChange(OauthVars oauthVars, Uri url) async {
    final code = url.queryParameters["code"];

    if (!url.toString().contains(malRedirectUri) || code == null) {
      return;
    }

    final body = {
      "grant_type": "authorization_code",
      "client_id": malClientId,
      "code": code,
      "code_verifier": oauthVars.codeVerifier,
      "redirect_uri": malRedirectUri,
    };

    final response = await http.post(
      Uri.parse("https://myanimelist.net/v1/oauth2/token"),
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: body.entries.map((e) => "${e.key}=${e.value}").join("&"),
    );

    if (response.statusCode != 200) {
      return;
    }

    final token = await MalToken.getInstance(
      json: jsonDecode(response.body),
    );

    if (context.mounted) {
      MyApp.of(context)!.setToken(token);
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: _isWebviewSuspended ? "Resume webview" : "Suspend webview",
        onPressed: () async {
          await (_isWebviewSuspended
              ? _controller.resume()
              : _controller.suspend());

          setState(() {
            _isWebviewSuspended = !_isWebviewSuspended;
          });
        },
        child: Icon(_isWebviewSuspended ? Icons.play_arrow : Icons.pause),
      ),
      appBar: AppBar(
        title: StreamBuilder<String>(
          stream: _controller.title,
          builder: (context, snapshot) {
            return Text(
              snapshot.hasData ? snapshot.data! : "WebView (Windows) Example",
            );
          },
        ),
      ),
      body: Center(
        child: compositeView(),
      ),
    );
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("WebView permission requested"),
        content: Text("WebView has requested permission '$kind'"),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text("Deny"),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text("Allow"),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    _controller.dispose();
    super.dispose();
  }
}
