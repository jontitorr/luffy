import "dart:async";

import "package:html/parser.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/http_client.dart";
import "package:luffy/util.dart";

String _fixQuality(String quality) {
  const qualities = {
    "ultra": "2160p",
    "quad": "1440p",
    "full": "1080p",
    "hd": "720p",
    "sd": "480p",
    "low": "360p",
    "lowest": "240p",
    "mobile": "144p",
  };

  return qualities[quality.toLowerCase()] ?? quality;
}

Future<List<VideoSource>> okruExtractor(
  String url, {
  String prefix = "",
  bool fixQualities = true,
}) async {
  try {
    final res = await HttpClient.get(url);
    final document = parse(res.data);
    final videosString = document
            .querySelector("div[data-options]")
            ?.attributes["data-options"]!
            .substringAfter(r'\"videos\":[{\"name\":\"')
            .substringBefore("]") ??
        "";

    final ret = <VideoSource>[];

    for (final value in videosString.split(r'{\"name\":\"').reversed) {
      final videoUrl = value
          .substringAfter(r'url\":\"')
          .substringBefore(r'\"')
          .replaceAll(r"\\\u0026", "&");
      final quality = value.substringBefore(r'\"');
      final fixedQuality = fixQualities ? _fixQuality(quality) : quality;
      final videoQuality =
          '${prefix.isNotEmpty ? '$prefix ' : ''}Okru - $fixedQuality';
      if (videoUrl.startsWith("https://")) {
        ret.add(VideoSource(videoUrl: videoUrl, description: videoQuality));
      }
    }
    return ret;
  } catch (_) {
    return [];
  }
}
