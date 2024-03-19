import "dart:async";

import "package:html/parser.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/util.dart";

Future<List<VideoSource>> streamtapeExtractor(
  String url, {
  String quality = "StreamTape",
}) async {
  try {
    const baseUrl = "https://streamtape.com/e/";
    final newUrl =
        !url.startsWith(baseUrl) ? "$baseUrl${url.split("/")[4]}" : url;

    final response = await http.get(Uri.parse(newUrl));
    final document = parse(response.body);

    const targetLine = "document.getElementById('robotlink')";
    String script = "";
    final scri = document
        .querySelectorAll("script")
        .where((element) => element.innerHtml.contains(targetLine))
        .map((e) => e.innerHtml)
        .toList();
    if (scri.isEmpty) {
      return [];
    }
    script = scri.first.split("$targetLine.innerHTML = '").last;
    final videoUrl =
        "https:${script.substringBefore("'")}${script.substringAfter("+ ('xcd").substringBefore("'")}";

    return [VideoSource(videoUrl: videoUrl, description: quality)];
  } catch (_) {
    return [];
  }
}
