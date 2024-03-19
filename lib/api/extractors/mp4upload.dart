import "package:html/parser.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/js_unpacker.dart";
import "package:luffy/util.dart";

final _qualityRegex = RegExp(r"\WHEIGHT=(\d+)");
const _referer = "https://mp4upload.com/";

Future<List<VideoSource>> mp4UploadExtractor(
  String url, {
  Map<String, String> headers = const {},
  String prefix = "",
  String suffix = "",
}) async {
  final newHeaders = Map<String, String>.from(headers)
    ..addAll({"referer": _referer});

  try {
    final response = await http.get(Uri.parse(url), headers: newHeaders);
    String script = "";

    final document = parse(response.body);
    final scriptElementWithEval = document
        .querySelectorAll("script")
        .where(
          (script) =>
              script.text.contains("eval") &&
              script.text.contains("p,a,c,k,e,d"),
        )
        .map((script) => script.text)
        .toList();

    if (scriptElementWithEval.isNotEmpty) {
      script = JsUnpacker.unpack(script).first;
    } else {
      final document = parse(response.body);
      final scriptElementWithSrc = document
          .querySelectorAll("script")
          .where((script) => script.innerHtml.contains("player.src"))
          .map((script) => script.innerHtml)
          .toList();
      if (scriptElementWithSrc.isNotEmpty) {
        script = scriptElementWithSrc.first;
      } else {
        return [];
      }
    }

    final videoUrl = script
        .substringAfter(".src(")
        .substringBefore(")")
        .substringAfter("src:")
        .substringAfter('"')
        .substringBefore('"');
    final resolutionMatch = _qualityRegex.firstMatch(script);
    final resolution = resolutionMatch?.group(1) ?? "Unknown resolution";
    final quality = "$prefix Mp4Upload - ${resolution}p $suffix";

    return [
      VideoSource(
        videoUrl: videoUrl,
        description: quality,
        headers: newHeaders,
      ),
    ];
  } catch (_) {
    return [];
  }
}
