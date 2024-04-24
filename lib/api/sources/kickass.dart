import "dart:convert";

import "package:crypto/crypto.dart";
import "package:hex/hex.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/util.dart";

const _baseUrl = "https://kickassanime.am";

class KickassAnime extends AnimeSource {
  Future<String?> _getImageUrl(Map<String, dynamic>? posterData) async {
    final formats = posterData?["formats"] ?? [];

    if (formats.isEmpty || posterData == null) {
      return null;
    }

    return "$_baseUrl/image/poster/${posterData["hq"] ?? posterData["sm"]}.${formats.first}";
  }

  @override
  Future<List<Anime>> search(String query) async {
    final ret = <Anime>[];

    try {
      final res = await http.post(
        Uri.parse("$_baseUrl/api/search"),
        headers: {
          "Content-Type": "application/json",
          "Referer": "$_baseUrl/",
          "Origin": _baseUrl,
        },
        body: jsonEncode({"query": query}),
      );

      final data = jsonDecode(res.body);

      for (final item in data) {
        ret.add(
          Anime(
            title: item["title_en"] ?? item["title"],
            url: "${item["slug"]}",
            imageUrl: await _getImageUrl(item["poster"]),
          ),
        );
      }
    } catch (e) {
      prints("Failed to search anime: $e");
    }

    return ret;
  }

  @override
  Future<List<Episode>> getEpisodes(Anime anime) async {
    final ret = <Episode>[];

    try {
      var res = await http.get(
        Uri.parse(
          "$_baseUrl/api/show/${anime.url}/episodes?lang=ja-JP&page=1",
        ),
      );

      var data = jsonDecode(res.body);

      Future<Episode> fromJson(dynamic item) async => Episode(
            title: item["title"],
            url: jsonEncode({
              "anime": anime.url,
              "episode": "ep-${item["episode_string"]}-${item["slug"]}",
            }),
            thumbnailUrl: await _getImageUrl(item["poster"]),
          );

      ret.addAll(
        await Future.wait<Episode>(
          (data["result"] ?? []).map<Future<Episode>>(fromJson),
        ),
      );

      // Keep going until we get no more episodes.
      for (var i = 1; i < (data["pages"] ?? []).length; i++) {
        final item = data["pages"][i];

        res = await http.get(
          Uri.parse(
            "$_baseUrl/api/show/${anime.url}/episodes?lang=ja-JP&page=${item["number"]}",
          ),
        );

        data = jsonDecode(res.body);

        ret.addAll(
          await Future.wait<Episode>(
            (data["result"] ?? []).map<Future<Episode>>(fromJson),
          ),
        );
      }
    } catch (e) {
      prints("Failed to get episodes: $e");
    }

    return ret;
  }

  @override
  Future<List<VideoSource>> getSources(Episode episode) async {
    final ret = <VideoSource>[];

    // try {
    final params = jsonDecode(episode.url);

    var res = await http.get(
      Uri.parse(
        "$_baseUrl/api/show/${params["anime"]}/episode/${params["episode"]}",
      ),
    );

    var data = jsonDecode(res.body);

    for (final server in data["servers"]) {
      final String? shortName = server["shortName"]?.toLowerCase();
      final Uri? url = server["src"] != null ? Uri.parse(server["src"]) : null;

      if (shortName == null || url == null) {
        continue;
      }

      final order = jsonDecode(
        (await http.get(
          Uri.parse(
            "https://raw.githubusercontent.com/enimax-anime/gogo/main/KAA.json",
          ),
        ))
            .body,
      )[shortName];
      final playerHtml = (await http.get(
        url,
      ))
          .body;
      final isBirb = shortName == "bird";
      final usesMid = shortName == "duck";
      final cid = playerHtml.split("cid:")[1].split("'")[1].trim();
      final metaData = utf8.decode(HEX.decode(cid));
      final sigArray = [];

      try {
        res = await http.get(
          Uri.parse(
            "https://raw.githubusercontent.com/enimax-anime/kaas/$shortName/key.txt",
          ),
        );

        if (res.statusCode != 200) {
          throw Exception("Status Code: ${res.statusCode}");
        }
      } catch (e) {
        res = await http.get(
          Uri.parse(
            "https://raw.githubusercontent.com/enimax-anime/kaas/duck/key.txt",
          ),
        );
      }

      final key = res.body;
      final route =
          metaData.split("|")[1].replaceAll("player.php", "source.php");
      final mid = url.queryParameters[usesMid ? "mid" : "id"];
      const userAgent =
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/89.0.142.86 Safari/537.36";

      final signatureItems = {
        "SIG": playerHtml.split("signature:")[1].split("'")[1].trim(),
        "USERAGENT": userAgent,
        "IP": metaData.split("|")[0],
        "ROUTE": route,
        "KEY": key,
        "TIMESTAMP": DateTime.now().millisecondsSinceEpoch ~/ 1000,
        "MID": mid,
      };

      for (final item in order) {
        sigArray.add(signatureItems[item]);
      }

      final sig = sha1.convert(utf8.encode(sigArray.join())).toString();

      res = await http.get(
        Uri.parse(
          "${url.origin}$route?${usesMid ? "mid" : "id"}=$mid${isBirb ? "" : '&e=${signatureItems["TIMESTAMP"]}'}&s=$sig",
        ),
        headers: {
          "Referer":
              "${url.origin}${route.replaceAll("source.php", "player.php")}?${usesMid ? "mid" : "id"}=$mid",
          "User-Agent": userAgent,
        },
      );

      data = jsonDecode(res.body);
      prints(data);
    }
    // } catch (e) {
    // prints("Failed to get sources: $e");
    // }

    return ret;
  }

  @override
  String get name => "KickassAnime";
}
