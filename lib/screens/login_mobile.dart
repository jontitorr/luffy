import "dart:convert";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:http/http.dart" as http;
import "package:luffy/auth.dart";
import "package:luffy/main.dart";

const malRedirectUri = "https://localhost/authorize";

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

class LoginMobileScreen extends StatefulWidget {
  const LoginMobileScreen({super.key});

  @override
  State<LoginMobileScreen> createState() => _LoginMobileScreenState();
}

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

class _LoginMobileScreenState extends State<LoginMobileScreen> {
  final _webViewKey = GlobalKey();
  late Future<OauthVars> _oauthVars;

  final settings = InAppWebViewSettings(
    contentBlockers: [
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: r".*(ads|pinterest|addthis|icon|disqus|amung|bidgear).*",
        ),
        action: ContentBlockerAction(
          type: ContentBlockerActionType.BLOCK,
        ),
      ),
    ],
    useShouldOverrideUrlLoading: true,
  );

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

  Future<void> handleNavigationStateChange(OauthVars oauthVars, Uri url) async {
    if (!url.toString().contains(malRedirectUri)) {
      return;
    }

    final code = url.queryParameters["code"];

    if (code == null) {
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
  void initState() {
    super.initState();
    _oauthVars = setupOauthVars();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Log In",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          centerTitle: true,
        ),
        body: FutureBuilder<OauthVars>(
          future: _oauthVars,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }

            if (!snapshot.hasData) {
              return const Center(child: SizedBox.shrink());
            }

            final oauthVars = snapshot.data;

            if (oauthVars == null) {
              return const Center(child: SizedBox.shrink());
            }

            return Column(
              children: [
                Expanded(
                  child: InAppWebView(
                    key: _webViewKey,
                    initialUrlRequest:
                        URLRequest(url: WebUri(oauthVars.loginUrl)),
                    initialSettings: settings,
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      final url = navigationAction.request.url;

                      if (url == null) {
                        return NavigationActionPolicy.CANCEL;
                      }

                      handleNavigationStateChange(oauthVars, url);

                      return url.toString().contains(malRedirectUri)
                          ? NavigationActionPolicy.CANCEL
                          : NavigationActionPolicy.ALLOW;
                    },
                    onPermissionRequest: (controller, request) async {
                      return PermissionResponse(
                        resources: request.resources,
                        action: PermissionResponseAction.GRANT,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
