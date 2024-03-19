import "package:html/parser.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/js_unpacker.dart";
import "package:luffy/util.dart";

Future<List<VideoSource>> filemoonExtractor(
  String url,
  String prefix,
  String suffix,
) async {
  final res = await http.get(Uri.parse(url));
  final document = parse(res.body);

  // We want script:containsData(eval)
  final elements = document.querySelectorAll("script");

  final jsE = elements.where((element) {
    return element.text.contains("eval");
  }).first;

  final unpacked = JsUnpacker.unpack(jsE.text).toString();
  final masterUrl = unpacked.substringAfter('{file:"').substringBefore('"}');
  final masterPlaylistRes = await http.get(Uri.parse(masterUrl));
  final masterPlaylist = masterPlaylistRes.body;

  return masterPlaylist
      .substringAfter("#EXT-X-STREAM-INF:")
      .split("#EXT-X-STREAM-INF:")
      .map((it) {
    final quality =
        "$prefix ${it.substringAfter("RESOLUTION=").substringAfter("x").substringBefore(",")}p";
    final videoUrl = it.substringAfter("\n").substringBefore("\n");

    final videoHeaders = {
      "Accept": "*/*",
      "Host": Uri.parse(videoUrl).host,
      "Origin": "https://${Uri.parse(videoUrl).host}",
      "Referer": "https://${Uri.parse(videoUrl).host}/",
    };

    return VideoSource(
      videoUrl: videoUrl,
      description: "$prefix - $quality $suffix",
      headers: videoHeaders,
    );
  }).toList();
}
