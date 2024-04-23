import "dart:convert";

import "package:collection/collection.dart";
import "package:html/dom.dart";
import "package:html/parser.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/api/extractors/filemoon.dart";
import "package:luffy/api/extractors/mp4upload.dart";
import "package:luffy/api/extractors/streamtape.dart";
import "package:luffy/http_client.dart";
import "package:luffy/util.dart";

const _baseUrl = "https://aniwave.to";

List<int> rc4Encrypt(String key, List<int> message) {
  final List<int> key0 = utf8.encode(key);
  int i0 = 0, j = 0;
  final List<int> box = List.generate(256, (i) => i);

  int x = 0;
  for (int i = 0; i < 256; i++) {
    x = (x + box[i] + key0[i % key0.length]) % 256;
    final tmp = box[i];
    box[i] = box[x];
    box[x] = tmp;
  }

  final List<int> out = [];
  for (final char in message) {
    i0 = (i0 + 1) % 256;
    j = (j + box[i0]) % 256;

    final tmp = box[i0];
    box[i0] = box[j];
    box[j] = tmp;

    final c = char ^ (box[(box[i0] + box[j]) % 256]);
    out.add(c);
  }

  return out;
}

String vrfDecrypt(String input) {
  final decode = base64Url.decode(input);
  final rc4 = rc4Encrypt("hlPeNwkncH0fq9so", decode);
  return Uri.decodeComponent(utf8.decode(rc4));
}

List<int> vrfShift(List<int> vrf) {
  final shifts = [-3, 3, -4, 2, -2, 5, 4, 5];
  for (var i = 0; i < vrf.length; i++) {
    final shift = shifts[i % 8];
    vrf[i] = (vrf[i] + shift) & 0xFF;
  }
  return vrf;
}

List<int> rot13(List<int> vrf) {
  for (var i = 0; i < vrf.length; i++) {
    final byte = vrf[i];
    if (byte >= "A".codeUnitAt(0) && byte <= "Z".codeUnitAt(0)) {
      vrf[i] = (byte - "A".codeUnitAt(0) + 13) % 26 + "A".codeUnitAt(0);
    } else if (byte >= "a".codeUnitAt(0) && byte <= "z".codeUnitAt(0)) {
      vrf[i] = (byte - "a".codeUnitAt(0) + 13) % 26 + "a".codeUnitAt(0);
    }
  }
  return vrf;
}

String vrfEncrypt(String input) {
  final rc4 = rc4Encrypt("ysJhV6U27FVIjjuk", input.codeUnits);
  final vrf = base64Url.encode(rc4);
  final vrf1 = base64.encode(vrf.codeUnits);
  final List<int> vrf2 = vrfShift(vrf1.runes.toList());
  final vrf3 = base64.encode(vrf2);
  return utf8.decode(rot13(vrf3.runes.toList()));
}

List<VideoSource> parseVizPlaylist(
  String masterPlaylist,
  Uri masterUrl,
  String prefix,
  Map<String, String> embedReferer,
) {
  final playlistHeaders = Map<String, String>.from(embedReferer)
    ..addAll({
      "host": masterUrl.host,
      "connection": "keep-alive",
    });

  return masterPlaylist
      .substringAfter("#EXT-X-STREAM-INF:")
      .split("#EXT-X-STREAM-INF:")
      .map((it) {
    final quality =
        "$prefix ${it.substringAfter("RESOLUTION=").substringAfter("x").substringBefore("\n")}p";

    final videoUrl =
        "${masterUrl.toString().substringBeforeLast("/")}/${it.substringAfter("\n").substringBefore("\n").trim()}";
    return VideoSource(
      videoUrl: videoUrl,
      description: quality,
      headers: playlistHeaders,
    );
  }).toList();
}

Future<List<Anime>> _searchAnimeParse(
  AnimeParser parser,
  String response,
  String url,
) async {
  return parse(response)
      .querySelectorAll(parser.searchAnimeSelector)
      .map(parser.searchAnimeFromElement)
      .toList();
}

class NineAnimeExtractor extends AnimeExtractor implements AnimeParser {
  @override
  String get name => "9anime";

  @override
  String get searchAnimeSelector => "div.ani.items > div.item";

  @override
  String get episodeSelector => "div.episodes ul > li > a";

  Future<List<Anime>> searchAnime(String query) async {
    final url = "$_baseUrl/filter?keyword=$query";
    return http.get(Uri.parse(url)).then(
          (res) => _searchAnimeParse(
            this,
            res.body,
            url,
          ),
        );
  }

  @override
  Future<List<Episode>> getEpisodes(Anime anime) async {
    var res = await HttpClient.get(_baseUrl + anime.url);
    final document = parse(res.data);
    final id = document.querySelector("div[data-id]")?.attributes["data-id"];

    if (id == null) {
      return [];
    }

    final encrypt = vrfEncrypt(id);
    final vrf = "vrf=${Uri.encodeComponent(encrypt)}";
    res = await HttpClient.get(
      "$_baseUrl/ajax/episode/list/$id?$vrf",
      headers: {
        "Accept": "application/json, text/javascript, */*; q=0.01",
        "Referer": _baseUrl + anime.url,
        "X-Requested-With": "XMLHttpRequest",
      },
    );
    final html = res.data["result"];

    if (html == null) {
      return [];
    }

    return parse(html)
        .querySelectorAll(episodeSelector)
        .map((e) => episodeFromElement(e, anime.url))
        .toList();
  }

  @override
  Future<List<VideoSource>> getSources(Episode episode) async {
    return getVideoList(episode);
  }

  Future<List<VideoSource>> getVideoList(Episode episode) async {
    final ids = episode.url.substringBefore("&");
    final encrypt = vrfEncrypt(ids);
    final vrf = "vrf=${Uri.encodeComponent(encrypt)}";
    final res =
        await http.get(Uri.parse("$_baseUrl/ajax/server/list/$ids?$vrf"));
    final html = jsonDecode(res.body)["result"];
    final ret = <VideoSource>[];
    final vidElements =
        parse(html).querySelectorAll("div.servers > div").toList();

    for (final element in vidElements) {
      final type = element.attributes["data-type"] ?? "";
      final serversIds = element
          .querySelectorAll("li")
          .map((e) => e.attributes["data-link-id"])
          .whereNotNull()
          .toList();

      for (final serverId in serversIds) {
        final encrypt = vrfEncrypt(serverId);
        final vrf = "vrf=${Uri.encodeComponent(encrypt)}";
        final res =
            await http.get(Uri.parse("$_baseUrl/ajax/server/$serverId?$vrf"));
        final status = jsonDecode(res.body)["status"];

        if (status == 200) {
          final url = vrfDecrypt(jsonDecode(res.body)["result"]["url"]);
          if (url.contains("mp4upload")) {
            ret.addAll(await mp4UploadExtractor(url, suffix: type));
          } else if (url.contains("streamtape")) {
            ret.addAll(
              await streamtapeExtractor(url, quality: "StreamTape - $type"),
            );
          } else if (url.contains("filemoon")) {
            ret.addAll(await filemoonExtractor(url, "", type));
          }
        }
      }
    }

    return ret;
  }

  @override
  Future<List<Anime>> search(String query) {
    return searchAnime(query);
  }

  @override
  Anime searchAnimeFromElement(Element element) {
    final aTag = element.querySelector("a.name");
    final title = aTag?.text ?? "";
    final thumbnail =
        element.querySelector("div.poster img")?.attributes["src"];
    final url = aTag?.attributes["href"] ?? "";

    return Anime(
      title: title,
      imageUrl: thumbnail ?? "",
      url: url,
    );
  }

  @override
  Episode episodeFromElement(Element element, String url) {
    final ids = element.attributes["data-ids"];
    final epNum = element.attributes["data-num"] ?? "";
    final name =
        element.parent?.querySelector("span.d-title")?.text.trim() ?? "";

    return Episode(
      title:
          "Episode $epNum${name.isNotEmpty && name != "Episode $epNum" ? ": $name" : ""}",
      url: "$ids&epurl=$url/ep-$epNum",
    );
  }
}
