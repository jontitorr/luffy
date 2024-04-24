import "dart:convert";

import "package:cookie_jar/cookie_jar.dart";
import "package:dio/dio.dart";
import "package:dio_cookie_manager/dio_cookie_manager.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/util.dart";

const _baseUrl = "https://api.animeflix.live";

final _dio = () {
  final ret = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  ret.interceptors.add(CookieManager(CookieJar()));

  return ret;
}();

const _headers = {
  "referer": "https://animeflix.live/",
  "X-Requested-With": "XMLHttpRequest",
};

const _servers = [
  "moon",
  "sun",
  "rock",
  "bacon",
  "hq",
  "crunchy",
  "zoro",
  "allanime",
  "gogo",
];
final _sourceRegex = RegExp(r"const source = '([^']+)'");

class AnimeData {
  AnimeData.fromJson(Map<String, dynamic> json)
      : id = json["_id"],
        title = json["title"] != null
            ? Map<String, String?>.from(json["title"])
            : null,
        type = json["type"],
        anilistID = json["anilistID"],
        malID = json["malID"],
        synonyms = json["synonyms"] is List<dynamic>
            ? List<String>.from(json["synonyms"].whereType<String>())
            : null,
        description = json["description"],
        episodeNum = json["episodeNum"],
        genres =
            json["genres"] != null ? List<String>.from(json["genres"]) : null,
        status = json["status"],
        season = json["season"],
        averageScore = json["averageScore"],
        nextAiringEpisode = json["nextAiringEpisode"] != null
            ? AiringEpisode.fromJson(json["nextAiringEpisode"])
            : null,
        trailerVideo = json["trailerVideo"],
        startDate =
            json["startDate"] != null ? Date.fromJson(json["startDate"]) : null,
        endDate =
            json["endDate"] != null ? Date.fromJson(json["endDate"]) : null,
        updatedAt = json["updatedAt"],
        bannerImage = json["bannerImage"],
        images =
            json["images"] != null ? Images.fromJson(json["images"]) : null,
        duration = json["duration"],
        slug = json["slug"],
        logoart = json["logoart"],
        style = json["style"] != null ? List<String>.from(json["style"]) : null;

  final String? id;
  final Map<String, String?>? title;
  final String? type;
  final String? anilistID;
  final String? malID;
  final List<String>? synonyms;
  final String? description;
  final int? episodeNum;
  final List<String>? genres;
  final String? status;
  final String? season;
  final String? averageScore;
  final AiringEpisode? nextAiringEpisode;
  final String? trailerVideo;
  final Date? startDate;
  final Date? endDate;
  final int? updatedAt;
  final String? bannerImage;
  final Images? images;
  final int? duration;
  final String? slug;
  final String? logoart;
  final List<String>? style;

  Map<String, dynamic> toJson() => {
        "_id": id,
        "title": title,
        "type": type,
        "anilistID": anilistID,
        "malID": malID,
        "synonyms": synonyms,
        "description": description,
        "episodeNum": episodeNum,
        "genres": genres,
        "status": status,
        "season": season,
        "averageScore": averageScore,
        "nextAiringEpisode": nextAiringEpisode,
        "trailerVideo": trailerVideo,
        "startDate": startDate,
        "endDate": endDate,
        "updatedAt": updatedAt,
        "bannerImage": bannerImage,
        "images": images,
        "duration": duration,
        "slug": slug,
        "logoart": logoart,
        "style": style,
      };
}

class AiringEpisode {
  AiringEpisode.fromJson(Map<String, dynamic> json)
      : airingAt = json["airingAt"],
        episode = json["episode"];

  final int? airingAt;
  final int? episode;

  Map<String, dynamic> toJson() => {
        "airingAt": airingAt,
        "episode": episode,
      };
}

class Date {
  Date.fromJson(Map<String, dynamic> json)
      : year = json["year"],
        month = json["month"],
        day = json["day"];

  final int? year;
  final int? month;
  final int? day;

  Map<String, dynamic> toJson() => {
        "year": year,
        "month": month,
        "day": day,
      };
}

class Images {
  Images.fromJson(Map<String, dynamic> json)
      : large = json["large"],
        medium = json["medium"],
        small = json["small"];

  final String? large;
  final String? medium;
  final String? small;

  Map<String, dynamic> toJson() => {
        "large": large,
        "medium": medium,
        "small": small,
      };
}

class EpisodeData {
  EpisodeData.fromJson(Map<String, dynamic> json)
      : number =
            json["number"] is int ? json["number"].toDouble() : json["number"],
        title = json["title"],
        description = json["description"],
        image = json["image"],
        slug = json["slug"];

  final double number;
  final String? title;
  final String? description;
  final String? image;
  // User Added for remembering the anime slug.
  final String slug;

  Map<String, dynamic> toJson() => {
        "number": number,
        "title": title,
        "description": description,
        "image": image,
        "slug": slug,
      };
}

Future<VideoSource?> _getVideoUrl(Uri watchUri, {String? currentSource}) async {
  try {
    final source = await (() async {
      if (currentSource != null) {
        return currentSource;
      }

      final res = await _dio.get(
        watchUri.toString(),
        options: Options(headers: _headers, responseType: ResponseType.json),
      );

      if (res.statusCode != 200) {
        return null;
      }

      final data = res.data;
      final source = data["source"] as String?;

      return source;
    })();

    if (source == null) {
      return null;
    }

    final sourceRes = await _dio.get(
      source,
      options: Options(headers: _headers),
    );

    final match = _sourceRegex.firstMatch(
      sourceRes.data,
    );

    if (match == null) {
      return null;
    }

    // Try to get the video url.
    final videoUrl = match.group(1)!;

    Response<dynamic> videoRes;

    try {
      videoRes = await _dio.get(
        videoUrl,
        options: Options(headers: _headers),
      );
    } on DioException catch (e) {
      prints("Failed to get video url: $e");
      return null;
    }

    if (videoRes.statusCode != 200) {
      return null;
    }

    return VideoSource(
      videoUrl: videoUrl,
      description: source,
    );
  } on DioException {
    return null;
  }
}

class AnimeFlix extends AnimeSource {
  @override
  String get name => "AnimeFlix";

  @override
  Future<List<Anime>> search(String query) async {
    try {
      final res = await _dio.get(
        "$_baseUrl/info?query=${Uri.encodeComponent(query)}&limit=15",
        options: Options(headers: _headers, responseType: ResponseType.json),
      );

      if (res.statusCode == 200) {
        if (res.data == null) {
          return [];
        }

        return List<Anime>.from(
          res.data.map(
            (e) => Anime(
              title: e["title"]?["userPreferred"] ??
                  e["title"]?["romaji"] ??
                  e["title"]?["english"] ??
                  e["title"]?["native"] ??
                  "Unknown",
              imageUrl: e["images"]?["large"] ?? "",
              url: e,
            ),
          ),
        );
      }
    } catch (e) {
      prints("Failed to search anime AnimeFlix: $e");
    }

    return [];
  }

  @override
  Future<List<Episode>> getEpisodes(Anime anime) async {
    // FIXME: Probably should just have serialized the slug but its cool ig.
    final slug = AnimeData.fromJson(jsonDecode(anime.url)).slug;

    try {
      final res = await _dio.get(
        "$_baseUrl/episodes?id=$slug&dub=false",
        options: Options(headers: _headers, responseType: ResponseType.json),
      );

      if (res.statusCode == 200) {
        final data = res.data;
        final episodes = data["episodes"];

        if (episodes != null) {
          return List<Episode>.from(
            episodes.map((e) {
              e["slug"] = slug; // Add slug to the episode data. [User Added
              final episodeData = EpisodeData.fromJson(e);

              return Episode(
                title: episodeData.title,
                url: jsonEncode(episodeData.toJson()),
                thumbnailUrl: episodeData.image,
                synopsis: episodeData.description,
              );
            }),
          );
        }
      }
    } on DioException catch (e) {
      prints("Failed to get episodes AnimeFlix: $e");
    }

    return [];
  }

  @override
  Future<List<VideoSource>> getSources(Episode episode) async {
    final episodeData = EpisodeData.fromJson(jsonDecode(episode.url));
    final slug = episodeData.slug;
    final number = episodeData.number;
    final watchUrl = Uri.parse("$_baseUrl/watch/$slug-episode-$number?server=");

    try {
      final res = await _dio.get(
        watchUrl.toString(),
        options: Options(headers: _headers, responseType: ResponseType.json),
      );

      if (res.statusCode == 200) {
        final data = res.data;
        final source = data["source"] as String?;
        final sourceUrl = Uri.parse(source ?? "");
        final firstServer = sourceUrl.queryParameters["server"];
        final servers = sourceUrl.queryParameters["servers"];

        if (firstServer == null || servers == null) {
          return [];
        }

        final firstServerIdx = _servers.indexOf(firstServer);
        var videoRes = await _getVideoUrl(sourceUrl, currentSource: source);

        if (firstServerIdx == -1 || videoRes != null) {
          return [videoRes!];
        }

        // If our previous thing failed it means the first one failed so start with the next 1 we have.
        for (var i = (firstServerIdx + 1) % _servers.length;
            i != firstServerIdx;
            i = (i + 1) % _servers.length) {
          // TODO(xminent): Once we can figure out the servers we can use this to skip servers that are down.
          // if (servers[i] == "0") {
          //   continue;
          // }

          final server = _servers[i];

          videoRes = await _getVideoUrl(
            watchUrl.replace(
              queryParameters: {
                "server": server,
              },
            ),
          );

          if (videoRes != null) {
            return [videoRes];
          }
        }
      }
    } on DioException catch (e) {
      prints("Failed to get video url AnimeFlix: $e");
    }

    return [];
  }
}
