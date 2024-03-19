import "dart:convert";

import "package:cached_network_image/cached_network_image.dart";
import "package:carousel_slider/carousel_slider.dart";
import "package:flutter/material.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/user_settings.dart";
import "package:luffy/screens/home.dart";
import "package:luffy/screens/login.dart";
import "package:luffy/util.dart";

class _Data {
  _Data({
    required this.description,
    required this.imageUrl,
  });

  _Data.fromJson(Map<String, dynamic> json)
      : description = json["description"],
        imageUrl = json["image"];

  final String description;
  final String imageUrl;
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late Future<List<_Data>> _dataFuture;

  Future<List<_Data>> _getData() async {
    final res = await http.get(
      Uri.parse(
        "https://gist.githubusercontent.com/jontitorr/933b1bedeba5aa71018ed40d54802f87/raw/419baffd17fafb14b1e636c3ed64cdc8f5ff41f3/luffy",
      ),
    );
    final data = jsonDecode(res.body);
    final ret = <_Data>[];

    for (final d in data) {
      ret.add(_Data.fromJson(d));
    }

    return ret;
  }

  @override
  void initState() {
    super.initState();
    _dataFuture = _getData();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Flexible(
            flex: 10,
            child: FutureBuilder(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data;

                if (data == null) {
                  return const Center(
                    child: Text("No data"),
                  );
                }

                return CarouselSlider(
                  options: CarouselOptions(
                    height: MediaQuery.of(context).size.height * 0.8,
                    autoPlay: true,
                    viewportFraction: 1,
                    enableInfiniteScroll: false,
                  ),
                  items: data.map((e) {
                    return Builder(
                      builder: (context) {
                        return Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: e.imageUrl,
                              fit: BoxFit.cover,
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.height * 0.8,
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black.withOpacity(0.8),
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  e.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Button which says Register,
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text("Register"),
                ),
                // Button which says Login
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  child: const Text("Login"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // hyperlink that says continue without an account (is clickable).
          Flexible(
            child: GestureDetector(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  ),
                );
              },
              child: Text(
                "Continue without an account",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    UserSettings.setWelcomeScreenShown(true).then((_) {
      prints("Set welcome screen shown.");
    });

    super.dispose();
  }
}
