import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/screens/video_player.dart";
import "package:url_launcher/url_launcher.dart";

class AnimeBrowser extends StatefulWidget {
  const AnimeBrowser({super.key});

  @override
  State<AnimeBrowser> createState() => _AnimeBrowserState();
}

class _AnimeBrowserState extends State<AnimeBrowser> {
  InAppWebViewController? webViewController;
  final webViewKey = GlobalKey();
  final whiteListDomains = ["www.google.com", "gogoanime.cl", "9anime.to"];

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

  PullToRefreshController? pullToRefreshController;
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  @override
  void initState() {
    super.initState();

    pullToRefreshController = kIsWeb
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                webViewController?.loadUrl(
                  urlRequest:
                      URLRequest(url: await webViewController?.getUrl()),
                );
              }
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search)),
              controller: urlController,
              keyboardType: TextInputType.url,
              onSubmitted: (value) {
                var url = WebUri(value);

                if (url.scheme.isEmpty) {
                  url = WebUri("https://www.google.com/search?q=$value");
                }

                webViewController?.loadUrl(urlRequest: URLRequest(url: url));
              },
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    key: webViewKey,
                    initialUrlRequest: URLRequest(
                      url: WebUri("https://9anime.to/watch/one-piece.ov8/ep-1"),
                    ),
                    initialSettings: settings,
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onPermissionRequest: (controller, request) async {
                      return PermissionResponse(
                        resources: request.resources,
                        action: PermissionResponseAction.GRANT,
                      );
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      final url = navigationAction.request.url;

                      if (url == null) {
                        return NavigationActionPolicy.CANCEL;
                      }

                      if (![
                        "http",
                        "https",
                        "file",
                        "chrome",
                        "data",
                        "javascript",
                        "about",
                      ].contains(url.scheme)) {
                        if (await canLaunchUrl(url)) {
                          // Launch the App
                          await launchUrl(
                            url,
                          );
                          // and cancel the request
                          return NavigationActionPolicy.CANCEL;
                        }
                      }

                      return whiteListDomains.contains(url.host)
                          ? NavigationActionPolicy.ALLOW
                          : NavigationActionPolicy.CANCEL;
                    },
                    onLoadStop: (controller, url) async {
                      pullToRefreshController?.endRefreshing();
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onReceivedError: (controller, request, error) {
                      pullToRefreshController?.endRefreshing();
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress == 100) {
                        pullToRefreshController?.endRefreshing();
                      }

                      setState(() {
                        this.progress = progress / 100;
                        urlController.text = url;
                      });
                    },
                    onUpdateVisitedHistory: (controller, url, androidIsReload) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    // How we capture the m3u8 url and pass it to the video player.
                    shouldInterceptRequest: (controller, request) {
                      final url = request.url.toString();

                      // If the url ends in .m3u8, we want to launch the video player.
                      if (url.endsWith(".m3u8")) {
                        // Make the request and check if EXTINF is in the response.
                        // If it is, we know it's a valid m3u8 file.
                        // http.get(Uri.parse(url)).then((response) {
                        //   if (response.body.contains("EXTINF")) {
                        //     // If it is, we want to launch the video player.
                        //     Navigator.push(
                        //         context,
                        //         MaterialPageRoute(
                        //             builder: (context) =>
                        //                 VideoPlayerScreen(title: "Video", url: url)));
                        //   }
                        // });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                              showId: "test",
                              showTitle: "Video",
                              episode: Episode(
                                title: "Video",
                                url: "",
                              ),
                              episodeNum: 0,
                              sourceName: "Anime Browser",
                              imageUrl: "",
                              episodes: const [],
                              sourceFetcher: (Episode e) async => [
                                VideoSource(
                                  videoUrl: url,
                                  description: "Anime Browser",
                                ),
                              ],
                              showUrl: "",
                              languages: const [],
                            ),
                          ),
                        );

                        // if (context.mounted) {
                        //   Navigator.push(
                        //       context,
                        //       MaterialPageRoute(
                        //           builder: (context) =>
                        //               VideoPlayerScreen(title: "Video", url: url)));
                        // }
                      }

                      return Future.value();
                    },
                  ),
                  if (progress < 1.0)
                    LinearProgressIndicator(value: progress)
                  else
                    Container(),
                ],
              ),
            ),
            ButtonBar(
              alignment: MainAxisAlignment.center,
              children: <Widget>[
                ElevatedButton(
                  child: const Icon(Icons.arrow_back),
                  onPressed: () {
                    webViewController?.goBack();
                  },
                ),
                ElevatedButton(
                  child: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    webViewController?.goForward();
                  },
                ),
                ElevatedButton(
                  child: const Icon(Icons.refresh),
                  onPressed: () {
                    webViewController?.reload();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
