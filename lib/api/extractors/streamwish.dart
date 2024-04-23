import "package:color_log/color_log.dart";
import "package:html/parser.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/js_unpacker.dart";
import "package:luffy/util.dart";

Future<List<VideoSource>> streamWishExtractor(String url, String prefix) async {
  final ret = <VideoSource>[];

  try {
    final res = await http.get(Uri.parse(url));
    final document = parse(res.body);
    final jsEval = document
        .querySelectorAll("script")
        .where((element) => element.text.contains("m3u8"))
        .map((element) => element.text)
        .toList();

    if (jsEval.isEmpty) {
      return [];
    }

    final masterUrl = jsEval.firstOrNull
        .let(
          (script) {
            if (script.contains("function(p,a,c")) {
              return JsUnpacker.unpack(script).first;
            }
            return script;
          },
        )
        ?.substringAfter("source")
        .substringAfter('file:"')
        .substringBefore('"');

    if (masterUrl == null || masterUrl.isEmpty) {
      return [];
    }

    final playlistHeaders = {
      "Accept": "*/*",
      "Host": Uri.parse(masterUrl).host,
      "Origin": "https://${Uri.parse(url).host}",
      "Referer": "https://${Uri.parse(url).host}/",
    };

    final masterBase =
        '${'https://${Uri.parse(masterUrl).host}${Uri.parse(masterUrl).path}'.substringBeforeLast('/')}/';

    final masterPlaylistResponse =
        await http.get(Uri.parse(masterUrl), headers: playlistHeaders);
    final masterPlaylist = masterPlaylistResponse.body;

    const separator = "#EXT-X-STREAM-INF:";
    masterPlaylist.substringAfter(separator).split(separator).forEach((it) {
      final quality =
          '$prefix - ${it.substringAfter('RESOLUTION=').substringAfter('x').substringBefore(',')}p ';
      final videoUrl =
          masterBase + it.substringAfter("\n").substringBefore("\n");
      ret.add(
        VideoSource(
          videoUrl: videoUrl,
          description: quality,
          headers: playlistHeaders,
        ),
      );
    });

    return ret;
  } catch (e) {
    prints("Failed to extract StreamWish: $e", level: LogLevel.error);
    return [];
  }
}
