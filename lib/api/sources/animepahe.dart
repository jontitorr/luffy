import "package:dio/dio.dart";
import "package:html/parser.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/ddos_interceptor.dart";
import "package:luffy/api/extractors/kwik.dart";
import "package:luffy/http_client.dart";
import "package:luffy/util.dart";

const _baseUrl = "https://animepahe.com";

Future<String?> _getSession(String title, int animeId) async {
  try {
    return (await DdosGuardInterceptor.get("$_baseUrl/api?m=search&q=$title"))
        .data["data"]
        ?.firstWhere(
          (e) => e["id"] == animeId,
          orElse: () => null,
        )?["session"];
  } catch (e) {
    prints("Failed to get session $e");
    return null;
  }
}

class _SearchData {
  _SearchData.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        title = json["title"],
        type = json["type"],
        episodes = json["episodes"],
        status = json["status"],
        season = json["season"],
        year = json["year"],
        score = json["score"]?.toDouble(),
        poster = json["poster"],
        session = json["session"],
        relevance = json["relevance"];

  final int? id;
  final String title;
  final String? type;
  final int? episodes;
  final String? status;
  final String? season;
  final int? year;
  final double? score;
  final String? poster;
  final String session;
  final String? relevance;
}

class _Search {
  _Search.fromJson(Map<String, dynamic> json)
      : total = json["total"],
        data = List<_SearchData>.from(
          json["data"].map((x) => _SearchData.fromJson(x)),
        );

  final int total;
  final List<_SearchData> data;
}

class AnimePaheExtractor extends AnimeExtractor {
  @override
  String get name => "AnimePahe";

  @override
  Future<List<Anime>> search(String query) async {
    try {
      final res = await DdosGuardInterceptor.get(
        "$_baseUrl/api?m=search&l=8&q=$query",
      );
      final data = _Search.fromJson(res.data);

      return data.data
          .where((e) => e.id != null)
          .map(
            (e) => Anime(
              title: e.title,
              imageUrl: e.poster ?? "",
              url: "/anime/?anime_id=${e.id}",
            ),
          )
          .toList();
    } catch (e) {
      prints("Failed to search $e");
      return [];
    }
  }

  Future<List<Episode>> _parseEpisodePage(
    List<dynamic> items,
    String animeSession,
  ) async {
    return List<Episode>.from(
      items.map((e) {
        final epNum = e["episode"];
        String epName;
        if (epNum == epNum.toInt()) {
          epName = epNum.toInt().toString();
        } else {
          epName = epNum.toString();
        }

        return Episode(
          title: "Episode $epName",
          url: "/play/$animeSession/${e["session"]}",
        );
      }),
    );
  }

  Future<Response<dynamic>> _nextPageRequest(String url, int page) async {
    return HttpClient.get(
      "${url.substringBeforeLast("&page=")}&page=$page",
    );
  }

  Future<List<Episode>> _parseEpisodePages(
    Response<dynamic> res,
    String session,
  ) async {
    final page = res.data["current_page"];
    final hasNextPage = page < res.data["last_page"];
    final ret = await _parseEpisodePage(res.data["data"], session);
    if (hasNextPage) {
      final nextPage =
          await _nextPageRequest(res.requestOptions.uri.toString(), page + 1);
      ret.addAll(await _parseEpisodePages(nextPage, session));
    }

    return ret;
  }

  @override
  Future<List<Episode>> getEpisodes(Anime anime) async {
    final session = await _getSession(
      anime.title,
      int.parse(
        anime.url.substringAfterLast("?anime_id=").substringBefore('"'),
      ),
    );

    if (session == null) {
      return [];
    }

    try {
      final res = await HttpClient.get(
        "$_baseUrl/api?m=release&id=$session&sort=episode_desc&page=1",
      );
      return (await _parseEpisodePages(res, session)).reversed.toList();
    } catch (e) {
      prints("Failed to get episodes $e");
      return [];
    }
  }

  Future<VideoSource?> _getVideo(
    String paheUrl,
    String kwikUrl,
    String quality,
  ) async {
    return (await getStreamUrlFromKwik(paheUrl)).let(
      (url) => VideoSource(
        videoUrl: url,
        description: quality,
      ),
    );
  }

  @override
  Future<List<VideoSource>> getSources(Episode episode) async {
    final res = await HttpClient.get(
      "$_baseUrl${episode.url}",
    );
    final document = parse(res.data);
    final downloadLinks = document.querySelectorAll(
      "div#pickDownload > a",
    );
    final ret = <VideoSource>[];
    final buttons = document.querySelectorAll("div#resolutionMenu > button");

    for (int i = 0; i < buttons.length; i++) {
      final btn = buttons[i];
      final source = await _getVideo(
        downloadLinks[i].attributes["href"]!,
        btn.attributes["data-src"]!,
        btn.text,
      );

      if (source != null) {
        ret.add(source);
      }
    }

    return ret;
  }
}
