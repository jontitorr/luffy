import "dart:math";

import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/util.dart";

String _randomString({int length = 10}) {
  const allowedChars =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  return List.generate(
    length,
    (index) =>
        allowedChars.runes.elementAt(Random().nextInt(allowedChars.length)),
  ).join();
}

Future<List<VideoSource>> doodExtractor(
  String url, {
  String? quality,
  bool redirect = true,
}) async {
  final newQuality = quality ?? ('Doodstream ${redirect ? ' mirror' : ''}');

  try {
    final res = await http.get(Uri.parse(url));
    final newUrl = redirect ? res.request!.url.toString() : url;
    final doodHost = RegExp("https://(.*?)/").firstMatch(newUrl)!.group(1)!;
    final content = res.body;

    if (!content.contains("'/pass_md5/")) {
      return [];
    }

    return [
      VideoSource(
        videoUrl: newUrl,
        description: newQuality,
        headers: {
          "User-Agent": "Luffy",
          "Referer": "https://$doodHost/",
        },
      ),
    ];
  } catch (e) {
    prints("Failed to extract Doodstream: $e");
    return [];
  }
}
