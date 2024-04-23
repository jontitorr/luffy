import "dart:convert";

import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:html/parser.dart";
import "package:http/http.dart" as http;
import "package:luffy/auth.dart";
import "package:luffy/main.dart";
import "package:luffy/util.dart";
import "package:tuple/tuple.dart";

int _apiReqCounter = 0;
const _storage = FlutterSecureStorage();

class _HttpClient {
  static Future<http.Response> get(
    String url, {
    BuildContext? context,
    Map<String, String>? headers,
  }) async {
    final res = await http.get(Uri.parse(url), headers: headers);

    if (res.statusCode == 401 && url.startsWith(_malApiBaseUrl)) {
      await MalToken.invalidate();
      if (context != null) {
        MyApp.of(context)!.setToken(null);
      }
    }

    return res;
  }
}

class Relation {
  Relation({
    required this.id,
    required this.title,
    required this.url,
    required this.mediaType,
    required this.relationType,
  });

  Relation.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        title = json["title"],
        url = json["url"],
        mediaType = json["media_type"],
        relationType = json["relation_type"];

  final int id;
  final String title;
  final String url;
  final String mediaType;
  final String relationType;

  Map<String, dynamic> toJson() => {
        "id": id,
        "title": title,
        "url": url,
        "media_type": mediaType,
        "relation_type": relationType,
      };
}

class MalAnime {
  MalAnime({
    required this.id,
    required this.url,
    required this.imageUrl,
    required this.title,
    required this.status,
    required this.airing,
    required this.synopsis,
    required this.type,
    required this.episodes,
    required this.score,
    required this.startDate,
    required this.endDate,
    required this.members,
    required this.genres,
    required this.characters,
    required this.relations,
  });

  MalAnime.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        url = json["url"],
        imageUrl = json["main_picture"]["medium"],
        title = json["title"],
        status = json["status"],
        airing = json["airing"],
        synopsis = json["synopsis"],
        type = json["type"],
        episodes = json["episodes"],
        score = json["score"],
        startDate = json["start_date"],
        endDate = json["end_date"],
        members = json["members"],
        genres = json["genres"] != null
            ? List<String>.from(json["genres"].map((x) => x["name"]))
            : null,
        characters = json["characters"] != null
            ? List<AnimeCharacter>.from(
                json["characters"].map((x) => AnimeCharacter.fromJson(x)),
              )
            : null,
        relations = json["relations"] != null
            ? List<Relation>.from(
                json["relations"].map((x) => Relation.fromJson(x)),
              )
            : null;

  final int id;
  final String url;
  final String? imageUrl;
  final String title;
  final String status;
  final bool airing;
  final String? synopsis;
  final String? type;
  final int? episodes;
  final int? score;
  final String? startDate;
  final String? endDate;
  final int? members;
  final List<String>? genres;
  final List<AnimeCharacter>? characters;
  final List<Relation>? relations;

  Map<String, dynamic> toJson() => {
        "id": id,
        "url": url,
        "imageUrl": imageUrl,
        "title": title,
        "status": status,
        "airing": airing,
        "synopsis": synopsis,
        "type": type,
        "episodes": episodes,
        "score": score,
        "startDate": startDate,
        "endDate": endDate,
        "members": members,
        "genres": genres,
        "characters": characters,
        "relations": relations,
      };
}

class MalAnimeSearchResult {
  MalAnimeSearchResult({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.synopsis,
  });

  int id;
  String title;
  String imageUrl;
  String synopsis;
}

enum AnimeListStatus {
  watching,
  completed,
  onHold,
  dropped,
  planToWatch,
}

String _animeListStatusToString(AnimeListStatus status) {
  switch (status) {
    case AnimeListStatus.watching:
      return "watching";
    case AnimeListStatus.completed:
      return "completed";
    case AnimeListStatus.onHold:
      return "on_hold";
    case AnimeListStatus.dropped:
      return "dropped";
    case AnimeListStatus.planToWatch:
      return "plan_to_watch";
  }
}

class MalMyListStatus {
  MalMyListStatus({
    required this.status,
    required this.score,
    required this.numEpisodesWatched,
    required this.isRewatching,
    this.priority,
    this.numTimesRewatched,
    this.rewatchValue,
    this.tags,
    this.comments,
    required this.updatedAt,
  });

  final AnimeListStatus status;
  final int score;
  final int numEpisodesWatched;
  final bool isRewatching;
  final int? priority;
  final int? numTimesRewatched;
  final int? rewatchValue;
  final List<String>? tags;
  final String? comments;
  final String updatedAt;
}

class MalAnimeListWatchingEntry {
  MalAnimeListWatchingEntry({
    required this.anime,
    this.startDate,
    this.endDate,
    required this.myListStatus,
  });

  final MalAnimeSearchResult anime;
  final String? startDate;
  final String? endDate;
  final MalMyListStatus myListStatus;
}

const _malApiBaseUrl = "https://api.myanimelist.net/v2";

class MalAnimeEpisode {
  MalAnimeEpisode({required this.id, required this.title});

  final int id;
  final String title;
}

class SearchAnimeEpisodesResult {
  SearchAnimeEpisodesResult({
    required this.results,
    required this.totalPages,
  });

  final List<MalAnimeEpisode> results;
  final int totalPages;
}

class AnimeCharacter {
  AnimeCharacter({
    required this.name,
    required this.imageUrl,
  });

  AnimeCharacter.fromJson(Map<String, dynamic> json)
      : name = json["name"],
        imageUrl = json["image_url"];

  final String name;
  final String imageUrl;

  Map<String, dynamic> toJson() => {
        "name": name,
        "imageUrl": imageUrl,
      };
}

class TopAnimeResult {
  TopAnimeResult.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        title = json["title"],
        imageUrl = json["image_url"],
        type = animeTypeFromStr(json["type"]),
        score = json["score"],
        episodes = json["episodes"];

  final int id;
  final String title;
  final String imageUrl;
  final AnimeType type;
  final double score;
  final int episodes;
}

class SearchResult {
  SearchResult({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.synopsis,
    required this.type,
    required this.score,
  });

  final int id;
  final String title;
  final String imageUrl;
  final String synopsis;
  final String type;
  final double? score;
}

class Episode {
  Episode({
    required this.id,
    required this.url,
    required this.title,
    required this.titleJapanese,
    required this.titleRomaji,
    required this.aired,
    required this.score,
    required this.filler,
    required this.recap,
    required this.forumUrl,
  });

  Episode.fromJson(Map<String, dynamic> json)
      : id = json["mal_id"],
        url = json["url"],
        title = json["title"],
        titleJapanese = json["title_japanese"],
        titleRomaji = json["title_romanji"],
        aired = json["aired"] != null ? DateTime.parse(json["aired"]) : null,
        score = json["score"]?.toDouble(),
        filler = json["filler"],
        recap = json["recap"],
        forumUrl = json["forum_url"];

  final int id;
  final String? url;
  final String title;
  final String? titleJapanese;
  final String? titleRomaji;
  final DateTime? aired;
  final double? score;
  final bool filler;
  final bool recap;
  final String? forumUrl;
}

class UserInfo {
  UserInfo({
    required this.id,
    required this.name,
    required this.picture,
    required this.gender,
    required this.birthday,
    required this.location,
    required this.joinedAt,
    required this.timeZone,
    required this.isSupporter,
  });

  UserInfo.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        name = json["name"],
        picture = json["picture"],
        gender = json["gender"],
        birthday = json["birthday"],
        location = json["location"],
        joinedAt = DateTime.parse(json["joined_at"]),
        timeZone = json["time_zone"],
        isSupporter = json["is_supporter"];

  final int id;
  final String name;
  final String? picture;
  final String? gender;
  final String? birthday;
  final String location;
  final DateTime joinedAt;
  final String? timeZone;
  final bool? isSupporter;

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "picture": picture,
        "gender": gender,
        "birthday": birthday,
        "location": location,
        "joined_at": joinedAt.toIso8601String(),
        "time_zone": timeZone,
        "is_supporter": isSupporter,
      };
}

class MalService {
  static int apiReqCounter = 0;

  static Future<UserInfo?> getUserInfo({
    BuildContext? context,
  }) async {
    final token = await MalToken.getInstance();

    if (token == null) {
      return null;
    }

    try {
      final res = await _HttpClient.get(
        "$_malApiBaseUrl/users/@me",
        headers: {
          "Authorization": "Bearer ${token.accessToken}",
        },
        context: context,
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final ret = UserInfo.fromJson(jsonDecode(res.body));

      await _storage.write(key: "user_info", value: jsonEncode(ret.toJson()));

      return ret;
    } catch (e) {
      prints("Failed to get user info: $e");
      prints("Trying to get from storage...");

      final data = await _storage.read(key: "user_info");

      return data != null ? UserInfo.fromJson(jsonDecode(data)) : null;
    }
  }

  static Future<String?> getUserAvatar() async {
    final userInfo = await getUserInfo();

    return userInfo?.picture;
  }

  static Future<bool> isLoggedIn() async {
    return const FlutterSecureStorage().containsKey(key: "access_token");
  }

  static Future<List<AnimeCharacter>?> getAnimeCharacters(int id) async {
    try {
      final res = await _HttpClient.get(
        "https://myanimelist.net/anime/$id/anime/characters",
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Linux; Android 10; SAMSUNG SM-G965F) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/12.1 Chrome/79.0.3945.136 Mobile Safari/537.36",
        },
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final root = parse(res.body);
      final characterDivs = root.querySelectorAll(".box-unit4");
      final List<AnimeCharacter> characters = [];

      for (final div in characterDivs) {
        final aTag = div.querySelector(".character_name")?.querySelector("a");
        final previewUrl =
            div.querySelector(".lazyload")?.attributes["data-src"];

        if (aTag == null || previewUrl == null) {
          continue;
        }

        final name = aTag.text;
        final match =
            RegExp(r"/characters/(\d+)/(\d+)\.jpg").firstMatch(previewUrl);

        if (match == null) {
          continue;
        }

        final imageUrl =
            "https://cdn.myanimelist.net/images/characters/${match.group(1)}/${match.group(2)}.jpg";

        characters.add(
          AnimeCharacter(
            name: name,
            imageUrl: imageUrl,
          ),
        );
      }

      return characters;
    } catch (e) {
      prints("Failed to get anime characters: $e");
      return null;
    }
  }

  static Future<MalAnime?> getAnimeInfo(int id) async {
    try {
      final characters = await getAnimeCharacters(id);

      // prints("Got anime characters: ${jsonEncode(characters)}");

      final res =
          await _HttpClient.get("https://api.jikan.moe/v4/anime/$id/full");

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final data = jsonDecode(res.body)["data"];

      prints({"API_REQ_COUNTER": ++_apiReqCounter});

      final relations = <Relation>[];
      final relationsData = data["relations"] as List<dynamic>?;

      for (final relation in relationsData ?? []) {
        final entries = relation["entry"] as List<dynamic>?;
        final relationType = relation["relation"];

        for (final entry in entries ?? []) {
          final mediaType = entry["type"] as String;

          if (mediaType.toLowerCase() != "anime") {
            continue;
          }

          relations.add(
            Relation(
              id: entry["mal_id"],
              title: entry["name"],
              url: entry["url"],
              mediaType: entry["type"],
              relationType: relationType,
            ),
          );
        }
      }

      final anime = MalAnime(
        id: data["mal_id"],
        url: data["url"],
        imageUrl: data["images"]?["jpg"]?["large_image_url"],
        title: data["title"],
        status: data["status"],
        airing: data["airing"],
        synopsis: data["synopsis"],
        type: data["media_type"],
        episodes: data["episodes"],
        score: data["mean"],
        startDate: data["aired"]?["from"],
        endDate: data["aired"]?["to"],
        members: data["num_list_users"],
        genres: data["genres"]?.map((e) => e["name"]).toList().cast<String>(),
        characters: characters,
        relations: relations.isEmpty ? null : relations,
      );

      prints({"characters": characters?.length ?? "null"});

      await _storage.write(
        key: "anime_info_$id",
        value: jsonEncode(anime.toJson()),
      );

      return anime;
    } catch (e) {
      prints("Failed to get anime info: $e");
      prints("Trying to get from storage...");

      final data = await _storage.read(key: "anime_info_$id");

      return data != null ? MalAnime.fromJson(jsonDecode(data)) : null;
    }
  }

  static Future<SearchAnimeEpisodesResult?> searchAnimeEpisodes(
    int id,
    int page, {
    bool ascending = false,
  }) async {
    try {
      prints("searching anime episodes: $id (page: $page)");

      final pageToUse = page.clamp(1, double.infinity).toInt();

      final res = await _HttpClient.get(
        "https://api.jikan.moe/v4/anime/$id/episodes?page=$pageToUse",
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final data = jsonDecode(res.body);

      prints({"API_REQ_COUNTER": ++apiReqCounter});

      if (data == null ||
          data["pagination"] == null ||
          data["pagination"]["last_visible_page"] == null) {
        return null;
      }

      final endOfResults = data["pagination"]["last_visible_page"] == pageToUse;
      final lastPage = data["pagination"]["last_visible_page"];

      // SPECIAL CASE: If page is negative we want to count from the end.
      if (page == -1 && !endOfResults) {
        return searchAnimeEpisodes(id, lastPage, ascending: ascending);
      }

      if (data["data"] == null) {
        return null;
      }

      var results = (data["data"] as List).map<MalAnimeEpisode>((episode) {
        return MalAnimeEpisode(
          id: episode["mal_id"],
          title: episode["title"],
        );
      }).toList();

      if (!ascending) {
        results = List.from(results.reversed);
      }

      return SearchAnimeEpisodesResult(results: results, totalPages: lastPage);
    } catch (e) {
      prints("Failed to search anime episodes: $e");
      return null;
    }
  }

  static Future<int?> getAnimeEpisodeCount(int id) async {
    final token = await MalToken.getInstance();

    if (token == null) {
      return null;
    }

    try {
      final res = await _HttpClient.get(
        "$_malApiBaseUrl/anime/$id",
        headers: {
          "Authorization": "Bearer ${token.accessToken}",
        },
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final data = jsonDecode(res.body);

      prints({"API_REQ_COUNTER": ++apiReqCounter});

      if (data != null && data["num_episodes"] != null) {
        return data["num_episodes"];
      }

      // We have to try with Jikan.
      final episodes = await searchAnimeEpisodes(id, -1);
      final eps = episodes?.results;

      if (eps?.isEmpty ?? true) {
        return null;
      }

      var latestEpisodeId = eps![eps.length - 1].id;
      var missedEpisodes = 0;

      for (var i = eps.length - 2; i >= 0; i--) {
        final episode = eps[i];

        if (episode.id - latestEpisodeId != 1) {
          missedEpisodes++;
          continue;
        }

        latestEpisodeId = episode.id;
      }

      return latestEpisodeId + missedEpisodes;
    } catch (e) {
      prints("Failed to get anime episode count: $e");
      return null;
    }
  }

  static Future<AnimeList> getAnimeList() async {
    final userInfo = await getUserInfo();

    if (userInfo == null) {
      return AnimeList(
        watching: [],
        completed: [],
        onHold: [],
        dropped: [],
        planToWatch: [],
      );
    }

    try {
      final res = await _HttpClient.get(
        "https://myanimelist.net/animelist/${userInfo.name}&view=tile&status=7&order=5",
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Linux; Android 10; SAMSUNG SM-G965F) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/12.1 Chrome/79.0.3945.136 Mobile Safari/537.36",
        },
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final document = parse(res.body);
      final dataList = document.getElementById("app")?.attributes["data-list"];

      if (dataList == null || res.statusCode != 200) {
        throw Exception("Failed to get anime list");
      }

      final animeList = await _convertJsonToAnimeList(jsonDecode(dataList));

      // Store this data in case we have no internet.
      await _storage.write(
        key: "anime_list",
        value: jsonEncode(animeList.toJson()),
      );

      return animeList;
    } catch (e) {
      prints("Failed to get anime list: $e");
      prints("Trying to get from storage...");

      final data = await _storage.read(key: "anime_list");

      if (data == null) {
        return AnimeList(
          watching: [],
          completed: [],
          onHold: [],
          dropped: [],
          planToWatch: [],
        );
      }

      return AnimeList.fromJson(jsonDecode(data));
    }
  }

  static Future<http.Response?> updateAnimeListItem(
    int animeId,
    AnimeListStatus status, {
    int? score,
    int? numWatchedEpisodes,
  }) async {
    final token = await MalToken.getInstance();

    if (token == null) {
      return null;
    }

    try {
      final body = {
        "status": _animeListStatusToString(status),
      };

      if (score != null) {
        body["score"] = score.toString();
      }

      if (numWatchedEpisodes != null) {
        body["num_watched_episodes"] = numWatchedEpisodes.toString();
      }

      final res = await http.put(
        Uri.parse("$_malApiBaseUrl/anime/$animeId/my_list_status"),
        headers: {
          "Authorization": "Bearer ${token.accessToken}",
        },
        body: body,
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      prints({"API_REQ_COUNTER": ++apiReqCounter});

      // Get the original anime list.
      final data = await _storage.read(key: "anime_list_unformatted");

      if (data == null) {
        return res;
      }

      final unformattedList = await jsonDecode(data);
      final entry = unformattedList[animeId.toString()];

      if (entry == null) {
        return res;
      }

      final oldStatus = entry["status"];

      // Set the new values.
      entry["status"] = status.index;

      if (score != null) {
        entry["score"] = score;
      }

      if (numWatchedEpisodes != null) {
        entry["num_watched_episodes"] = numWatchedEpisodes;
      }

      // Update the unformatted anime list.
      await _storage.write(
        key: "anime_list_unformatted",
        value: jsonEncode(unformattedList),
      );

      // Update the anime list.
      final data2 = await _storage.read(key: "anime_list");

      if (data2 == null) {
        return res;
      }

      final animeList = AnimeList.fromJson(jsonDecode(data2));

      final toModify = (() {
        switch (AnimeListStatus.values[oldStatus]) {
          case AnimeListStatus.watching:
            return animeList.watching;
          case AnimeListStatus.completed:
            return animeList.completed;
          case AnimeListStatus.onHold:
            return animeList.onHold;
          case AnimeListStatus.dropped:
            return animeList.dropped;
          case AnimeListStatus.planToWatch:
            return animeList.planToWatch;
        }
      })();

      // Get the anime with the given id.
      final anime = toModify.firstWhereOrNull((e) => e.id == animeId);

      if (anime == null) {
        return res;
      }

      // Update the anime.
      anime.status = status;

      if (score != null) {
        anime.score = score;
      }

      if (numWatchedEpisodes != null) {
        anime.watchedEpisodes = numWatchedEpisodes;
      }

      // Update the anime list.
      await _storage.write(
        key: "anime_list",
        value: jsonEncode(animeList.toJson()),
      );

      return res;
    } catch (e) {
      prints("Failed to update anime list item: $e");
      return null;
    }
  }

  static Future<List<TopAnimeResult>?> getTopAnimes() async {
    try {
      final res = await _HttpClient.get(
        "https://gist.githubusercontent.com/zunjae/368b0550e9b2b0ce4318c4d3975e5d03/raw",
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final data = jsonDecode(res.body);

      prints({"API_REQ_COUNTER": ++apiReqCounter});

      final ret = <TopAnimeResult>[];

      for (final item in data) {
        ret.add(TopAnimeResult.fromJson(item));
      }

      return ret;
    } catch (e) {
      prints("Failed to get top animes: $e");
      return null;
    }
  }

  static Future<AnimeListEntry?> getListStatusFor(int animeId) async {
    // Attempt to get the list from the storage.
    final data = await _storage.read(key: "anime_list_unformatted");

    if (data == null) {
      return null;
    }

    final animeList = await jsonDecode(data);
    final anime = animeList[animeId.toString()];

    prints("Got our list status for anime: $animeId from storage: $anime");

    if (anime == null) {
      return null;
    }

    return AnimeListEntry.fromJson(anime);
  }

  static Future<List<SearchResult>?> search(String query) async {
    try {
      final res = await _HttpClient.get(
        "https://myanimelist.net/anime.php?q=$query&show=0",
        headers: {
          "User-Agent":
              "Mozilla/5.0 (Linux; Android 10; SAMSUNG SM-G965F) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/12.1 Chrome/79.0.3945.136 Mobile Safari/537.36",
        },
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final document = parse(res.body);
      final elements = document.querySelectorAll(".box-unit1");

      // Map through every element and inside it has a element with class "title". Get inner text for title.
      final ret = <SearchResult>[];

      for (final e in elements) {
        final aTag = e.querySelector("a");

        // If the a tag is null, skip this element.
        if (aTag == null) {
          prints("aTag is null");
          continue;
        }

        final id = aTag.attributes["href"]?.split("/")[4];
        final title = e.querySelector(".title")?.text;

        final score = e
            .querySelector(".fn-grey5.fs12.fw-n")
            ?.text
            .replaceAll(RegExp(r"[^0-9.]"), "");

        prints("Score: $score");

        final type = e.querySelector("dd")?.text;
        final synopsis = e.querySelector(".text")?.text;
        final imageUrl =
            e.querySelector(".icon-thumb img")?.attributes["data-src"];

        if (id == null ||
            title == null ||
            type == null ||
            synopsis == null ||
            imageUrl == null) {
          continue;
        }

        ret.add(
          SearchResult(
            id: int.parse(id),
            title: title,
            imageUrl: imageUrl,
            score: double.tryParse(score ?? ""),
            type: type,
            synopsis: synopsis,
          ),
        );
      }

      return ret;
    } catch (e) {
      prints("Failed to search anime: $e");
      return null;
    }
  }

  static Future<List<Episode>> getAnimeEpisodes(int animeId) async {
    final ret = <Episode>[];

    try {
      var res = await _HttpClient.get(
        "https://api.jikan.moe/v4/anime/$animeId/episodes?page=1",
      );

      var data = jsonDecode(res.body);
      var page = 2;

      for (final e in data["data"] ?? []) {
        ret.add(Episode.fromJson(e));
      }

      while (data["pagination"]?["has_next_page"] ?? false) {
        res = await _HttpClient.get(
          "https://api.jikan.moe/v4/anime/$animeId/episodes?page=${page++}",
        );

        data = jsonDecode(res.body);

        for (final e in data["data"] ?? []) {
          ret.add(Episode.fromJson(e));
        }
      }
    } catch (e) {
      prints("Failed to get anime episodes from Jikan: $e");
    }

    return ret;
  }
}

Future<AnimeList> _convertJsonToAnimeList(Map<String, dynamic> json) async {
  final Map<String, dynamic> items = json["items"];
  final List<AnimeListEntry> watching = [];
  final List<AnimeListEntry> completed = [];
  final List<AnimeListEntry> onHold = [];
  final List<AnimeListEntry> dropped = [];
  final List<AnimeListEntry> planToWatch = [];

  final extraDataMap = <int, Tuple2<AnimeListStatus, int>>{};
  final missingEpisodes = <int, Tuple2<AnimeListStatus, int>>{};

  items.forEach((_, item) {
    final id = item["id"] as int;
    final status = _getStatusFromUserStatusId(item["userStatusId"]);
    final totalEpisodes = item["totalEpisodes"] as int;

    final toModify = (() {
      switch (status) {
        case AnimeListStatus.watching:
          return watching;
        case AnimeListStatus.completed:
          return completed;
        case AnimeListStatus.onHold:
          return onHold;
        case AnimeListStatus.dropped:
          return dropped;
        case AnimeListStatus.planToWatch:
          return planToWatch;
      }
    })();

    extraDataMap[id] = Tuple2(status, toModify.length);

    if (totalEpisodes == 0) {
      missingEpisodes[id] = Tuple2(status, toModify.length);
    }

    final animeListEntry = AnimeListEntry(
      id: id,
      title: item["title"],
      imageUrl: "https://cdn.myanimelist.net${item['image']}",
      status: status,
      score: item["score"],
      watchedEpisodes: item["watchedEpisodes"],
      totalEpisodes: totalEpisodes == 0 ? null : totalEpisodes,
      isRewatching: item["reDoing"],
      startDate: null,
      endDate: null,
      coverImageUrl: null,
      kitsuId: null,
      titleEnJp: null,
      titleJaJp: null,
      type: null,
    );

    toModify.add(animeListEntry);
  });

  final animeList = AnimeList(
    watching: watching,
    completed: completed,
    onHold: onHold,
    dropped: dropped,
    planToWatch: planToWatch,
  );

  // Get the missing dates and combine all the IDs into one list.
  final extraDataIds = extraDataMap.keys.toList();

  final oldExtraDataIds =
      jsonDecode(await _storage.read(key: "extra_data_ids") ?? "null")
          as List<dynamic>?;

  if (oldExtraDataIds == null) {
    await _storage.write(
      key: "extra_data_ids",
      value: jsonEncode(extraDataIds),
    );
  }

  final extraData = await (() async {
    // If they are different from the old ones then we need to refetch.

    if (oldExtraDataIds != null) {
      if (oldExtraDataIds.length == extraDataIds.length &&
          oldExtraDataIds.toSet().difference(extraDataIds.toSet()).isEmpty) {
        final data = await _storage.read(key: "extra_data");

        if (data != null) {
          return jsonDecode(data);
        }
      } else {
        await _storage.write(
          key: "extra_data_ids",
          value: jsonEncode(extraDataIds),
        );
      }
    }

    try {
      final res = await http.post(
        Uri.parse("https://kanonapp.com/anime/KitsuInfo"),
        headers: {
          "apikey": "EUPP4UQDFJ435B5A900K",
          "Content-Type": "application/json",
        },
        body: jsonEncode(extraDataIds),
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final data = jsonDecode(res.body);

      await _storage.write(
        key: "extra_data",
        value: res.body,
      );

      return data;
    } catch (e) {
      prints("Failed to get extra data: $e");

      // Fetch a cached version of this response.
      final data = await _storage.read(key: "extra_data");

      if (data == null) {
        return [];
      }

      return jsonDecode(data);
    }
  })();

  extraData.forEach((data) {
    final id = data["MALId"] as int;

    if (!extraDataMap.containsKey(id)) {
      return;
    }

    final status = extraDataMap[id];
    final startDateStr = data["StartDate"] as String?;
    final endDateStr = data["EndDate"] as String?;
    final startDate =
        startDateStr != null ? DateTime.parse(startDateStr).toLocal() : null;
    final endDate =
        endDateStr != null ? DateTime.parse(endDateStr).toLocal() : null;

    if (status == null) {
      return;
    }

    final toModify = (() {
      switch (status.item1) {
        case AnimeListStatus.watching:
          return animeList.watching;
        case AnimeListStatus.completed:
          return animeList.completed;
        case AnimeListStatus.onHold:
          return animeList.onHold;
        case AnimeListStatus.dropped:
          return animeList.dropped;
        case AnimeListStatus.planToWatch:
          return animeList.planToWatch;
      }
    })()[status.item2];

    toModify.startDate = startDate;
    toModify.endDate = endDate;

    final kitsuId = data["KitsuId"] as int?;

    final coverImageUrl = kitsuId != null
        ? "https://media.kitsu.io/anime/cover_images/$kitsuId/large.jpg"
        : null;

    toModify.kitsuId = kitsuId;
    toModify.coverImageUrl = coverImageUrl;
    toModify.titleEnJp = data["TitleEnJp"];
    toModify.titleJaJp = data["TitleJaJp"];
    toModify.type = animeTypeFromStr(data["Type"]);
  });

  // Attempt to get missing episodes from this gist.

  if (missingEpisodes.isNotEmpty) {
    try {
      final res = await _HttpClient.get(
        "https://gist.githubusercontent.com/zunjae/06a5e039526121e6f25ef161cc850c2f/raw/",
      );

      if (res.statusCode != 200) {
        throw Exception("Status Code: ${res.statusCode}");
      }

      final data = jsonDecode(res.body);

      data.forEach((item) {
        final id = item["malid"] as int;

        if (!missingEpisodes.containsKey(id)) {
          return;
        }

        final status = missingEpisodes[id];
        final totalEpisodes = (item["episode"] as int) - 1;

        if (status == null) {
          return;
        }

        switch (status.item1) {
          case AnimeListStatus.watching:
            animeList.watching[status.item2].totalEpisodes = totalEpisodes;
            break;
          case AnimeListStatus.completed:
            animeList.completed[status.item2].totalEpisodes = totalEpisodes;
            break;
          case AnimeListStatus.onHold:
            animeList.onHold[status.item2].totalEpisodes = totalEpisodes;
            break;
          case AnimeListStatus.dropped:
            animeList.dropped[status.item2].totalEpisodes = totalEpisodes;
            break;
          case AnimeListStatus.planToWatch:
            animeList.planToWatch[status.item2].totalEpisodes = totalEpisodes;
            break;
        }
      });
    } catch (e) {
      prints("Failed to get missing episodes from gist: $e");
    }
  }

  // We need to make a map of all of our anime unformatted for easy lookup.
  final animeListUnformatted = <String, AnimeListEntry>{};

  void addToMap(AnimeListEntry entry) {
    animeListUnformatted[entry.id.toString()] = entry;
  }

  animeList.watching.forEach(addToMap);
  animeList.completed.forEach(addToMap);
  animeList.onHold.forEach(addToMap);
  animeList.dropped.forEach(addToMap);
  animeList.planToWatch.forEach(addToMap);

  await _storage.write(
    key: "anime_list_unformatted",
    value: jsonEncode(animeListUnformatted),
  );

  return animeList;
}

AnimeListStatus _getStatusFromUserStatusId(int userStatusId) {
  switch (userStatusId) {
    case 1:
      return AnimeListStatus.watching;
    case 2:
      return AnimeListStatus.completed;
    case 3:
      return AnimeListStatus.onHold;
    case 4:
      return AnimeListStatus.dropped;
    case 6:
      return AnimeListStatus.planToWatch;
    default:
      throw ArgumentError("Invalid userStatusId: $userStatusId");
  }
}

enum AnimeType {
  tv,
  movie,
  ova,
  ona,
  special,
  music,
}

AnimeType animeTypeFromStr(String str) {
  switch (str.toLowerCase()) {
    case "tv":
      return AnimeType.tv;
    case "movie":
      return AnimeType.movie;
    case "ova":
      return AnimeType.ova;
    case "ona":
      return AnimeType.ona;
    case "special":
      return AnimeType.special;
    case "music":
      return AnimeType.music;
    default:
      throw ArgumentError("Invalid anime type: $str");
  }
}

String animeTypeToStr(AnimeType type) {
  switch (type) {
    case AnimeType.tv:
      return "TV";
    case AnimeType.movie:
      return "Movie";
    case AnimeType.ova:
      return "OVA";
    case AnimeType.ona:
      return "ONA";
    case AnimeType.special:
      return "Special";
    case AnimeType.music:
      return "Music";
  }
}

class AnimeListEntry {
  AnimeListEntry({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.status,
    required this.score,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    required this.isRewatching,
    required this.startDate,
    required this.endDate,
    required this.kitsuId,
    required this.coverImageUrl,
    required this.titleEnJp,
    required this.titleJaJp,
    required this.type,
    this.extraData = "",
  });

  AnimeListEntry.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        title = json["title"],
        imageUrl = json["imageUrl"],
        status = AnimeListStatus.values[json["status"]],
        score = json["score"],
        watchedEpisodes = json["watchedEpisodes"],
        totalEpisodes = json["totalEpisodes"],
        isRewatching = json["isRewatching"],
        startDate = json["startDate"] != null
            ? DateTime.parse(json["startDate"])
            : null,
        endDate =
            json["endDate"] != null ? DateTime.parse(json["endDate"]) : null,
        kitsuId = json["kitsuId"],
        coverImageUrl = json["coverImageUrl"],
        titleEnJp = json["titleEnJp"],
        titleJaJp = json["titleJaJp"],
        type = json["type"] != null ? AnimeType.values[json["type"]] : null,
        extraData = "";

  int id;
  String title;
  String imageUrl;
  AnimeListStatus status;
  int? score;
  int watchedEpisodes;
  int? totalEpisodes;
  bool isRewatching;
  int? kitsuId;
  DateTime? startDate;
  DateTime? endDate;
  String? coverImageUrl;
  String? titleEnJp; // the title in english japanese
  String? titleJaJp; // the title in actual japanese
  AnimeType? type;
  String extraData;

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "imageUrl": imageUrl,
      "status": status.index,
      "score": score,
      "watchedEpisodes": watchedEpisodes,
      "totalEpisodes": totalEpisodes,
      "isRewatching": isRewatching,
      "startDate": startDate?.toIso8601String(),
      "endDate": endDate?.toIso8601String(),
      "kitsuId": kitsuId,
      "coverImageUrl": coverImageUrl,
      "titleEnJp": titleEnJp,
      "titleJaJp": titleJaJp,
      "type": type?.index,
    };
  }
}

class AnimeList {
  AnimeList({
    required this.watching,
    required this.completed,
    required this.onHold,
    required this.dropped,
    required this.planToWatch,
  });

  AnimeList.fromJson(Map<String, dynamic> json)
      : watching = (json["watching"] as List<dynamic>)
            .map((e) => AnimeListEntry.fromJson(e))
            .toList(),
        completed = (json["completed"] as List<dynamic>)
            .map((e) => AnimeListEntry.fromJson(e))
            .toList(),
        onHold = (json["onHold"] as List<dynamic>)
            .map((e) => AnimeListEntry.fromJson(e))
            .toList(),
        dropped = (json["dropped"] as List<dynamic>)
            .map((e) => AnimeListEntry.fromJson(e))
            .toList(),
        planToWatch = (json["planToWatch"] as List<dynamic>)
            .map((e) => AnimeListEntry.fromJson(e))
            .toList();

  final List<AnimeListEntry> watching;
  final List<AnimeListEntry> completed;
  final List<AnimeListEntry> onHold;
  final List<AnimeListEntry> dropped;
  final List<AnimeListEntry> planToWatch;

  Map<String, dynamic> toJson() {
    return {
      "watching": watching.map((e) => e.toJson()).toList(),
      "completed": completed.map((e) => e.toJson()).toList(),
      "onHold": onHold.map((e) => e.toJson()).toList(),
      "dropped": dropped.map((e) => e.toJson()).toList(),
      "planToWatch": planToWatch.map((e) => e.toJson()).toList(),
    };
  }
}
