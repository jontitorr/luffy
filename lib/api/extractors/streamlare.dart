import "dart:async";

import "package:luffy/api/anime.dart";
import "package:luffy/http_client.dart";
import "package:luffy/util.dart";

String _buildQuality(
  String resolution, [
  String prefix = "",
  String suffix = "",
]) =>
    "$prefix"
            "Streamlare:$resolution"
            "$suffix"
        .trim();

Future<List<VideoSource>> streamlareExtractor(
  String url, {
  String prefix = "",
  String suffix = "",
}) async {
  try {
    final id = url.split("/").last;
    final String playlist = (await HttpClient.post(
      "https://slwatch.co/api/video/stream/get",
      headers: {"Content-Type": "application/json"},
      data: '{"id":"$id"}',
    ))
        .data;

    final type = playlist.substringAfter('"type":"').substringBefore('"');

    if (type == "hls") {
      final masterPlaylistUrl = playlist
          .substringAfter('"file":"')
          .substringBefore('"')
          .replaceAll(r"\/", "/");
      final String masterPlaylist =
          (await HttpClient.get(masterPlaylistUrl)).data;

      const separator = "#EXT-X-STREAM-INF";
      return masterPlaylist
          .substringAfter(separator)
          .split(separator)
          .map((value) {
        final quality =
            '${value.substringAfter('RESOLUTION=').substringAfter('x').substringBefore(',')}p';
        final videoUrl = (() {
          final urlPart = value.substringAfter("\n").substringBefore("\n");
          return urlPart.startsWith("http")
              ? urlPart
              : masterPlaylistUrl.substringBefore("master.m3u8") + urlPart;
        })();

        return VideoSource(
          videoUrl: videoUrl,
          description: _buildQuality(quality, prefix, suffix),
        );
      }).toList();
    } else {
      const separator = '"label":"';
      final ret = <VideoSource>[];
      final values = playlist.substringAfter(separator).split(separator);

      for (final value in values) {
        final quality = value.substringAfter(separator).substringBefore('",');
        final apiUrl = value
            .substringAfter('"file":"')
            .substringBefore('",')
            .replaceAll(r"\", "");
        final response = await HttpClient.post(apiUrl);
        final videoUrl = response.requestOptions.uri.toString();

        ret.add(
          VideoSource(
            videoUrl: videoUrl,
            description: _buildQuality(quality, prefix, suffix),
          ),
        );
      }

      return ret;
    }
  } catch (e) {
    prints("Failed to extract streamlare: $e");
    return [];
  }
}
