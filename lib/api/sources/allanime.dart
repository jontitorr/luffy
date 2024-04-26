import "dart:convert";

import "package:collection/collection.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/extractors/allanime.dart";
import "package:luffy/api/extractors/dood.dart";
import "package:luffy/api/extractors/gogocdn.dart";
import "package:luffy/api/extractors/mp4upload.dart";
import "package:luffy/api/extractors/okru.dart";
import "package:luffy/api/extractors/streamlare.dart";
import "package:luffy/http_client.dart";
import "package:luffy/util.dart";

const _baseUrl = "https://allanime.ai";
const _apiUrl = "https://api.allanime.day/api";
const INTERAL_HOSTER_NAMES = [
  "Default",
  "Ac",
  "Ak",
  "Kir",
  "Rab",
  "Luf-mp4",
  "Si-Hls",
  "S-mp4",
  "Ac-Hls",
  "Uv-mp4",
  "Pn-Hls",
];

String _slugify(String input) {
  return input
      .replaceAll(RegExp(r"[^a-zA-Z0-9]"), "-")
      .replaceAll(RegExp(r"-{2,}"), "-")
      .toLowerCase();
}

extension StringDecrypt on String {
  String decryptSource() {
    return startsWith("-")
        ? substringAfterLast("-")
            .chunked(2)
            .map((it) => it.toInt(radix: 16).toByte())
            .toByteArray()
            .map((it) => (it ^ 56).toChar())
            .join()
        : this;
  }
}

class _Server {
  _Server(
    this.sourceUrl,
    this.sourceName,
    this.priority,
  );

  final String sourceUrl;
  final String sourceName;
  final double priority;
}

class AllAnime extends AnimeSource {
  @override
  Future<List<Episode>> getEpisodes(Anime anime) async {
    try {
      final id = anime.url.split("<&sep>").first;
      final res = await HttpClient.post(
        _apiUrl,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Referer": "https://api.allanime.day/",
        },
        data: jsonEncode({
          "variables": {
            "_id": id,
          },
          "query":
              "query (\$_id: String!){\nshow(\n_id:\$_id\n){\n_id\navailableEpisodesDetail\n}\n}",
        }),
      );
      final ret = <Episode>[];
      final episodes = res.data["data"]["show"]["availableEpisodesDetail"];

      (episodes["sub"] ?? []).forEach((e) {
        ret.add(
          Episode(
            title: "Episode $e (sub)",
            url: "$id<&sep>sub<&sep>$e",
          ),
        );
      });

      (episodes["dub"] ?? []).forEach((e) {
        ret.add(
          Episode(
            title: "Episode $e (dub)",
            url: "$id<&sep>dub<&sep>$e",
            isDub: true,
          ),
        );
      });

      return ret.reversed.toList();
    } catch (e) {
      prints("Failed to get episodes: $e");
      return [];
    }
  }

  @override
  Future<List<VideoSource>> getSources(Episode episode) async {
    final work = <Future<void>>[];
    final serverList = <_Server>[];
    final ret = <VideoSource>[];
    var i = 0;

    void addServer(String url, String name, double priority) {
      prints(
        "Adding server: $url, $name, $priority",
      );

      serverList.add(
        _Server(
          url,
          name,
          priority,
        ),
      );
    }

    try {
      final [id, type, number] = episode.url.split("<&sep>");

      final res = await HttpClient.post(
        _apiUrl,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Referer": "https://api.allanime.day/",
        },
        data: jsonEncode({
          "variables": {
            "showId": id,
            "translationType": type,
            "episodeString": number,
          },
          "query":
              "query(\n\$showId:String!,\n\$translationType: VaildTranslationTypeEnumType!,\n\$episodeString: String!\n) {\nepisode(\nshowId: \$showId\ntranslationType: \$translationType\nepisodeString: \$episodeString\n) {\nsourceUrls\n}\n}",
        }),
      );

      final mappings = [
        (
          "vidstreaming",
          [
            "vidstreaming",
            "https://gogo",
            "playgo1.cc",
            "playtaku",
          ]
        ),
        ("doodstream", ["dood"]),
        ("okru", ["ok.ru"]),
        ("mp4upload", ["mp4upload.com"]),
        ("streamlare", ["streamlare.com"]),
      ];

      for (final source in res.data["data"]["episode"]["sourceUrls"]) {
        final url = (source["sourceUrl"] as String).decryptSource();
        final name = source["sourceName"];
        final priority = source["priority"].toDouble();
        final type = source["type"];
        final matchingMapping = mappings
            .firstWhereOrNull((it) => it.$2.any((u) => url.contains(u)))
            ?.$1;

        if (url.startsWith("/apivtwo/") &&
            INTERAL_HOSTER_NAMES.any(
              (it) => it.toLowerCase() == name.toLowerCase(),
            )) {
          addServer(url, "internal $name", priority);
        } else if (type == "player") {
          addServer(url, "player@$name", priority);
        } else if (matchingMapping != null) {
          addServer(url, matchingMapping, priority);
        }
      }
    } catch (e) {
      prints("Failed to get: $e");
      return [];
    }

    void addWork(String sourceName, Future<List<VideoSource>> f) {
      work.add(
        Future(() async {
          try {
            prints("Calling $sourceName future");
            ret.addAll(await f);
          } catch (e) {
            prints("$sourceName future failed: $e");
            return Future.error(e);
          } finally {
            prints(
              "Finished $sourceName future | ${++i}/${work.length}",
            );
          }
        }),
      );
    }

    for (final server in serverList) {
      final sourceName = server.sourceName;

      if (sourceName.startsWith("internal ")) {
        addWork(sourceName, allanimeExtractor(server.sourceUrl, sourceName));
      } else if (sourceName.startsWith("player@")) {
        addWork(
          sourceName,
          Future(() async {
            final endpoint = (await HttpClient.get("$_baseUrl/getVersion"))
                .data["episodeIframeHead"];

            return [
              VideoSource(
                videoUrl: server.sourceUrl,
                description:
                    "Original (player ${sourceName.substringAfter("player@")})",
                headers: {
                  "Accept":
                      "video/webm,video/ogg,video/*;q=0.9,application/ogg;q=0.7,audio/*;q=0.6,*/*;q=0.5",
                  "Host": Uri.parse(server.sourceUrl).host,
                  "Referer": "$endpoint/",
                },
              ),
            ];
          }),
        );
      } else if (sourceName.startsWith("vidstreaming")) {
        addWork(
          sourceName,
          gogoCdnExtractor(
            server.sourceUrl.replaceFirst(RegExp(r"^//"), "https://"),
          ),
        );
      } else {
        [
          ("dood", doodExtractor(server.sourceUrl)),
          ("okru", okruExtractor(server.sourceUrl)),
          ("mp4upload", mp4UploadExtractor(server.sourceUrl)),
          ("streamlare", streamlareExtractor(server.sourceUrl)),
        ]
            .firstWhereOrNull((it) => sourceName == it.$1)
            .let((it) => addWork(sourceName, it.$2));
      }
    }

    try {
      await Future.wait(work);
    } catch (e) {
      prints("Failed to wait for work: $e");
    }

    return ret;
  }

  @override
  String get name => "AllAnime";

  @override
  Future<List<Anime>> search(String query) async {
    try {
      final res = await HttpClient.post(
        _apiUrl,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Referer": "https://api.allanime.day/",
        },
        data: jsonEncode({
          "variables": {
            "search": {
              "query": query,
              "allowAdult": false,
              "allowUnknown": false,
            },
            "limit": 26,
            "page": 1,
            "translationType": "sub",
            "countryOrigin": "ALL",
          },
          "query":
              "query(\n\$search:SearchInput\n\$limit:Int\n\$page:Int\n\$translationType:VaildTranslationTypeEnumType\n\$countryOrigin:VaildCountryOriginEnumType\n){\n shows(\n search:\$search\nlimit:\$limit\npage:\$page\ntranslationType:\$translationType\ncountryOrigin:\$countryOrigin\n){\n pageInfo{\n total\n}\n edges{\n _id\n name\n thumbnail\n englishName\n nativeName\n slugTime\n}\n}\n}",
        }),
      );

      final data = res.data["data"]["shows"]["edges"];
      final ret = <Anime>[];

      for (final it in data) {
        ret.add(
          Anime(
            // id: it["_id"],
            title: it["name"],
            imageUrl: it["thumbnail"],
            // nativeName: it["nativeName"],
            // englishName: it["englishName"],
            url:
                "${it["_id"]}<&sep>${it["slugTime"] ?? ""}<&sep>${_slugify(it["name"])}",
          ),
        );
      }

      return ret;
    } catch (e) {
      prints("Failed to search $e");
      return [];
    }
  }
}
