import "dart:convert";

import "package:http/http.dart" as http;
import "package:luffy/http_client.dart";
import "package:luffy/util.dart";

final _seasons = ["WINTER", "SPRING", "SUMMER", "FALL"];

DateTime? _parseDateObj(Map<String, dynamic> json) {
  return null;
}

String? _makeYoutubeUrl(Map<String, dynamic>? json) {
  if (json == null) {
    return null;
  }

  final site = json["site"];
  final id = json["id"];

  return site == "youtube" && id != null
      ? "https://www.youtube.com/embed/$id"
      : null;
}

class AnimeInfo {
  AnimeInfo({
    required this.id,
    required this.isFavorite,
    required this.siteUrl,
    required this.malId,
    this.nextAiringEpisode,
    required this.source,
    required this.countryOfOrigin,
    required this.format,
    required this.duration,
    required this.season,
    required this.seasonYear,
    required this.startDate,
    required this.endDate,
    required this.genres,
    required this.studios,
    required this.description,
    required this.trailer,
    required this.synonyms,
    required this.tags,
    required this.characters,
    required this.relations,
    required this.staff,
    required this.recommendations,
  });

  AnimeInfo.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        isFavorite = json["isFavourite"],
        siteUrl = json["siteUrl"],
        malId = json["idMal"],
        nextAiringEpisode = json["nextAiringEpisode"] != null
            ? NextAiringEpisode.fromJson(json["nextAiringEpisode"])
            : null,
        source = json["source"],
        countryOfOrigin = json["countryOfOrigin"],
        format = json["format"],
        duration = json["duration"],
        season = json["season"],
        seasonYear = json["seasonYear"],
        startDate = _parseDateObj(json["startDate"]),
        endDate = _parseDateObj(json["endDate"]),
        genres = List<String>.from(json["genres"] ?? []),
        studios = List<Studio>.from(
          json["studios"]["nodes"].map((x) => Studio.fromJson(x)),
        ),
        description = json["description"],
        trailer = _makeYoutubeUrl(json["trailer"]),
        synonyms = List<String>.from(json["synonyms"]),
        tags = List<Tag>.from(json["tags"].map((x) => Tag.fromJson(x))),
        characters = List<Character>.from(
          json["characters"]["edges"].map((x) => Character.fromJson(x)),
        ),
        relations = List<Relation>.from(
          json["relations"]["edges"].map((x) => Relation.fromJson(x)),
        ),
        staff = List<StaffPreview>.from(
          json["staffPreview"]["edges"].map((x) => StaffPreview.fromJson(x)),
        ),
        recommendations = List<SearchResult>.from(
          json["recommendations"]["nodes"]
              .where((node) => node["mediaRecommendation"] != null)
              .map((x) => SearchResult.fromJson(x["mediaRecommendation"])),
        );

  final int id;
  final bool isFavorite;
  final String siteUrl;
  final int? malId;
  final NextAiringEpisode? nextAiringEpisode;
  final String? source;
  final String countryOfOrigin;
  final String format;
  final int? duration;
  final String? season;
  final int? seasonYear;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> genres;
  final List<Studio> studios;
  final String? description;
  final String? trailer;
  final List<String> synonyms;
  final List<Tag> tags;
  final List<Character> characters;
  final List<Relation> relations;
  final List<StaffPreview> staff;
  final List<SearchResult> recommendations;
}

class NextAiringEpisode {
  NextAiringEpisode({
    required this.airingAt,
    required this.episode,
  });

  NextAiringEpisode.fromJson(Map<String, dynamic> json)
      : airingAt = DateTime.fromMillisecondsSinceEpoch(
          json["airingAt"],
        ),
        episode = json["episode"];

  final DateTime airingAt;
  final int episode;
}

class Studio {
  Studio({
    required this.id,
    required this.name,
    required this.siteUrl,
  });

  Studio.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        name = json["name"],
        siteUrl = json["siteUrl"];

  final int id;
  final String name;
  final String siteUrl;
}

class Character {
  Character({
    required this.role,
    required this.id,
    required this.image,
    required this.name,
  });

  Character.fromJson(Map<String, dynamic> json)
      : role = json["role"],
        id = json["node"]["id"],
        image = json["node"]["image"]["medium"],
        name = json["node"]["name"]["userPreferred"];

  final String role;
  final int id;
  final String? image;
  final String name;
}

class Relation extends SearchResult {
  Relation(
    this.relationType, {
    required super.id,
    required super.malId,
    required super.isAdult,
    required super.status,
    super.chapters,
    super.episodes,
    super.nextAiringEpisode,
    required super.type,
    required super.genres,
    required super.meanScore,
    required super.format,
    required super.bannerImage,
    required super.coverImage,
    required super.titleEnglish,
    required super.titleRomaji,
    required super.titleUserPreferred,
  });

  Relation.fromJson(Map<String, dynamic> json)
      : relationType = json["relationType"],
        super.fromJson(json["node"]);

  final String relationType;
}

class SearchResult {
  SearchResult({
    required this.id,
    required this.malId,
    required this.isAdult,
    required this.status,
    this.chapters,
    this.episodes,
    this.nextAiringEpisode,
    required this.type,
    required this.genres,
    required this.meanScore,
    required this.format,
    required this.bannerImage,
    required this.coverImage,
    required this.titleEnglish,
    required this.titleRomaji,
    required this.titleUserPreferred,
    this.languages = const [],
  });

  SearchResult.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        malId = json["idMal"],
        isAdult = json["isAdult"],
        status = json["status"],
        chapters = json["chapters"],
        episodes = json["episodes"],
        nextAiringEpisode = json["nextAiringEpisode"]?["episode"],
        type = json["type"],
        genres =
            json.containsKey("genres") ? List<String>.from(json["genres"]) : [],
        meanScore = json["meanScore"] != null
            ? json["meanScore"].toDouble() / 10
            : null,
        format = json["format"],
        bannerImage = json["bannerImage"],
        coverImage = json["coverImage"]["large"],
        titleEnglish = json["title"]["english"],
        titleRomaji = json["title"]["romaji"],
        titleUserPreferred = json["title"]["userPreferred"],
        languages = List<String>.from(
          (json["staff"]?["edges"] ?? []).map((x) => x["node"]["languageV2"]),
        ).toSet().toList();

  final int id;
  final int? malId;
  final bool isAdult;
  final String status;
  final int? chapters;
  final int? episodes;
  final int? nextAiringEpisode;
  final String type;
  final List<String> genres;
  final double? meanScore;
  final String? format;
  final String? bannerImage;
  final String coverImage;
  final String? titleEnglish;
  final String titleRomaji;
  final String titleUserPreferred;
  final List<String> languages;
}

class StaffPreview {
  StaffPreview({
    required this.role,
    required this.id,
    required this.name,
  });

  StaffPreview.fromJson(Map<String, dynamic> json)
      : role = json["role"],
        id = json["node"]["id"],
        name = json["node"]["name"]["userPreferred"];

  final String role;
  final int id;
  final String name;
}

class WeeklySearchResult {
  WeeklySearchResult({
    required this.episode,
    required this.airingAt,
    required this.media,
  });

  WeeklySearchResult.fromJson(Map<String, dynamic> json)
      : episode = json["episode"],
        airingAt = DateTime.fromMillisecondsSinceEpoch(
          json["airingAt"] * 1000,
        ),
        media = SearchResult.fromJson(json["media"]);

  final int episode;
  final DateTime airingAt;
  final SearchResult media;
}

class BrowseResult {
  BrowseResult.fromJson(Map<String, dynamic> json)
      : trending = json["trending"]["media"]
            .map<SearchResult>((json) => SearchResult.fromJson(json))
            .toList(),
        season = json["season"]["media"]
            .map<SearchResult>((json) => SearchResult.fromJson(json))
            .toList(),
        nextSeason = json["nextSeason"]["media"]
            .map<SearchResult>((json) => SearchResult.fromJson(json))
            .toList(),
        popular = json["popular"]["media"]
            .map<SearchResult>((json) => SearchResult.fromJson(json))
            .toList(),
        top = json["top"]["media"]
            .map<SearchResult>((json) => SearchResult.fromJson(json))
            .toList();

  final List<SearchResult> trending;
  final List<SearchResult> season;
  final List<SearchResult> nextSeason;
  final List<SearchResult> popular;
  final List<SearchResult> top;
}

class Tag {
  Tag({
    required this.name,
    required this.rank,
    required this.isMediaSpoiler,
  });

  Tag.fromJson(Map<String, dynamic> json)
      : name = json["name"],
        rank = json["rank"],
        isMediaSpoiler = json["isMediaSpoiler"];

  final String name;
  final int rank;
  final bool isMediaSpoiler;
}

class GenresAndTags {
  GenresAndTags({
    required this.genres,
    required this.tags,
  });

  GenresAndTags.fromJson(Map<String, dynamic> json)
      : genres = json["genres"],
        tags = json["tags"].map<Tag>((json) => Tag.fromJson(json)).toList();

  final List<String> genres;
  final List<String> tags;
}

class PageResult {
  PageResult({
    required this.pageInfo,
    required this.results,
  });

  PageResult.fromJson(Map<String, dynamic> json)
      : pageInfo = PageInfo.fromJson(json["pageInfo"]),
        results = json["media"]
            .map<SearchResult>((json) => SearchResult.fromJson(json))
            .toList();

  final PageInfo pageInfo;
  final List<SearchResult> results;
}

class PageInfo {
  PageInfo({
    required this.hasNextPage,
    required this.total,
  });

  PageInfo.fromJson(Map<String, dynamic> json)
      : hasNextPage = json["hasNextPage"],
        total = json["total"];

  final bool hasNextPage;
  final int total;
}

class AnilistService {
  static Future<List<SearchResult>> search(String query) async {
    final params = {
      "query":
          r"query($page:Int=1,$id:Int,$type:MediaType,$isAdult:Boolean=false,$search:String,$format:[MediaFormat],$status:MediaStatus,$countryOfOrigin:CountryCode,$source:MediaSource,$season:MediaSeason,$seasonYear:Int,$year:String,$onList:Boolean,$yearLesser:FuzzyDateInt,$yearGreater:FuzzyDateInt,$episodeLesser:Int,$episodeGreater:Int,$durationLesser:Int,$durationGreater:Int,$chapterLesser:Int,$chapterGreater:Int,$volumeLesser:Int,$volumeGreater:Int,$licensedBy:[String],$isLicensed:Boolean,$genres:[String],$excludedGenres:[String],$tags:[String],$excludedTags:[String],$minimumTagRank:Int,$sort:[MediaSort]=[POPULARITY_DESC,SCORE_DESC]){Page(page:$page,perPage:50){pageInfo{total perPage currentPage lastPage hasNextPage}media(id:$id,type:$type,season:$season,format_in:$format,status:$status,countryOfOrigin:$countryOfOrigin,source:$source,search:$search,onList:$onList,seasonYear:$seasonYear,startDate_like:$year,startDate_lesser:$yearLesser,startDate_greater:$yearGreater,episodes_lesser:$episodeLesser,episodes_greater:$episodeGreater,duration_lesser:$durationLesser,duration_greater:$durationGreater,chapters_lesser:$chapterLesser,chapters_greater:$chapterGreater,volumes_lesser:$volumeLesser,volumes_greater:$volumeGreater,licensedBy_in:$licensedBy,isLicensed:$isLicensed,genre_in:$genres,genre_not_in:$excludedGenres,tag_in:$tags,tag_not_in:$excludedTags,minimumTagRank:$minimumTagRank,sort:$sort,isAdult:$isAdult){id idMal isAdult status chapters episodes nextAiringEpisode{episode}type genres meanScore isFavourite format bannerImage coverImage{large extraLarge}title{english romaji userPreferred}mediaListEntry{progress private score(format:POINT_100)status}}}}",
      "variables":
          '{"type":"ANIME","isAdult":false,"page":"1","search":"$query" }',
    };

    try {
      final res = await http.post(
        Uri.parse("https://graphql.anilist.co/"),
        body: params,
      );

      if (res.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(res.body)["data"]["Page"]["media"];
      final ret = <SearchResult>[];

      for (final item in data) {
        if (item["media"]?["countryOfOrigin"] == "CN") {
          continue;
        }

        ret.add(SearchResult.fromJson(item));
      }

      return ret;
    } catch (e) {
      prints("Failed to get anime info: $e");
      return [];
    }
  }

  static Future<AnimeInfo?> getAnimeInfo(
    int id, {
    bool isMalId = false,
  }) async {
    final params = {
      "query":
          "{Media(${isMalId ? "idMal" : "id"}:$id){id mediaListEntry{id status score(format:POINT_100)progress private notes repeat customLists updatedAt startedAt{year month day}completedAt{year month day}}isFavourite siteUrl idMal nextAiringEpisode{episode airingAt}source countryOfOrigin format duration season seasonYear startDate{year month day}endDate{year month day}genres studios(isMain:true){nodes{id name siteUrl}}description trailer{site id}synonyms tags{name rank isMediaSpoiler}characters(sort:[ROLE,FAVOURITES_DESC],perPage:25,page:1){edges{role node{id image{medium}name{userPreferred}}}}relations{edges{relationType(version:2)node{id idMal mediaListEntry{progress private score(format:POINT_100)status}episodes chapters nextAiringEpisode{episode}popularity meanScore isAdult isFavourite format title{english romaji userPreferred}type status(version:2)bannerImage coverImage{large}}}}staffPreview:staff(perPage:8,sort:[RELEVANCE,ID]){edges{role node{id name{userPreferred}}}}recommendations(sort:RATING_DESC){nodes{mediaRecommendation{id idMal mediaListEntry{progress private score(format:POINT_100)status}episodes chapters nextAiringEpisode{episode}meanScore isAdult isFavourite format title{english romaji userPreferred}type status(version:2)bannerImage coverImage{large}}}}externalLinks{url site}}}",
    };

    final res = await http.post(
      Uri.parse("https://graphql.anilist.co"),
      body: params,
    );

    return AnimeInfo.fromJson(
      jsonDecode(res.body)["data"]["Media"],
    );
  }

  static Future<AnimeInfo?> getAnime(
    int page, {
    bool isMalId = false,
  }) async {
    final params = {
      "query":
          "{Page(page:$page,perPage:1){pageInfo{total perPage currentPage lastPage hasNextPage}media(type:ANIME,isAdult:false){title{romaji english native userPreferred}coverImage{large}description genres siteUrl bannerImage}}}",
    };

    final res = await http.post(
      Uri.parse("https://graphql.anilist.co"),
      body: params,
    );

    return AnimeInfo.fromJson(
      jsonDecode(res.body)["data"]["Media"],
    );
  }

  static Future<List<SearchResult>> discover() async {
    final params = {
      "query":
          r"query($page:Int=1,$id:Int,$type:MediaType,$isAdult:Boolean=false,$search:String,$format:[MediaFormat],$status:MediaStatus,$countryOfOrigin:CountryCode,$source:MediaSource,$season:MediaSeason,$seasonYear:Int,$year:String,$onList:Boolean,$yearLesser:FuzzyDateInt,$yearGreater:FuzzyDateInt,$episodeLesser:Int,$episodeGreater:Int,$durationLesser:Int,$durationGreater:Int,$chapterLesser:Int,$chapterGreater:Int,$volumeLesser:Int,$volumeGreater:Int,$licensedBy:[String],$isLicensed:Boolean,$genres:[String],$excludedGenres:[String],$tags:[String],$excludedTags:[String],$minimumTagRank:Int,$sort:[MediaSort]=[POPULARITY_DESC,SCORE_DESC]){Page(page:$page,perPage:12){pageInfo{total perPage currentPage lastPage hasNextPage}media(id:$id,type:$type,season:$season,format_in:$format,status:$status,countryOfOrigin:$countryOfOrigin,source:$source,search:$search,onList:$onList,seasonYear:$seasonYear,startDate_like:$year,startDate_lesser:$yearLesser,startDate_greater:$yearGreater,episodes_lesser:$episodeLesser,episodes_greater:$episodeGreater,duration_lesser:$durationLesser,duration_greater:$durationGreater,chapters_lesser:$chapterLesser,chapters_greater:$chapterGreater,volumes_lesser:$volumeLesser,volumes_greater:$volumeGreater,licensedBy_in:$licensedBy,isLicensed:$isLicensed,genre_in:$genres,genre_not_in:$excludedGenres,tag_in:$tags,tag_not_in:$excludedTags,minimumTagRank:$minimumTagRank,sort:$sort,isAdult:$isAdult){id idMal isAdult status chapters episodes nextAiringEpisode{episode}type genres meanScore isFavourite format bannerImage coverImage{large extraLarge}title{english romaji userPreferred}mediaListEntry{progress private score(format:POINT_100)status}}}}",
      "variables":
          '{"type":"ANIME","isAdult":false,"seasonYear":"2023" ,"season":"SUMMER","sort":"TRENDING_DESC"}',
    };

    try {
      final res = await http.post(
        Uri.parse("https://graphql.anilist.co"),
        body: params,
      );

      if (res.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(res.body)["data"]["Page"]["media"];
      final ret = <SearchResult>[];

      for (final item in data) {
        if (item["media"]?["countryOfOrigin"] == "CN") {
          continue;
        }

        ret.add(SearchResult.fromJson(item));
      }

      return ret;
    } catch (e) {
      prints("Failed to get anime info: $e");
      return [];
    }
  }

  static Future<List<SearchResult>> recentlyUpdated() async {
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();

    final params = {
      "query":
          "{Page(page:1,perPage:50){pageInfo{hasNextPage total}airingSchedules(airingAt_greater:0 airingAt_lesser:$now sort:TIME_DESC){episode airingAt media{id idMal status chapters episodes nextAiringEpisode{episode}isAdult type meanScore isFavourite format bannerImage countryOfOrigin coverImage{large}title{english romaji userPreferred}mediaListEntry{progress private score(format:POINT_100)status}}}}}",
      "variables": "",
    };

    try {
      final res = await http.post(
        Uri.parse("https://graphql.anilist.co"),
        body: params,
      );
      final data = jsonDecode(res.body)["data"]["Page"];
      final ret = <SearchResult>[];

      for (final item in data["airingSchedules"]) {
        final media = item["media"];

        if (media?["countryOfOrigin"] == "CN" || media?["isAdult"]) {
          continue;
        }

        ret.add(SearchResult.fromJson(media));
      }

      return ret;
    } catch (e) {
      prints("Failed to get anime info: $e");
      return [];
    }
  }

  static Future<PageResult?> popular(int page) async {
    final params = {
      "query":
          r"query($page:Int=1,$id:Int,$type:MediaType,$isAdult:Boolean=false,$search:String,$format:[MediaFormat],$status:MediaStatus,$countryOfOrigin:CountryCode,$source:MediaSource,$season:MediaSeason,$seasonYear:Int,$year:String,$onList:Boolean,$yearLesser:FuzzyDateInt,$yearGreater:FuzzyDateInt,$episodeLesser:Int,$episodeGreater:Int,$durationLesser:Int,$durationGreater:Int,$chapterLesser:Int,$chapterGreater:Int,$volumeLesser:Int,$volumeGreater:Int,$licensedBy:[String],$isLicensed:Boolean,$genres:[String],$excludedGenres:[String],$tags:[String],$excludedTags:[String],$minimumTagRank:Int,$sort:[MediaSort]=[POPULARITY_DESC,SCORE_DESC]){Page(page:$page,perPage:50){pageInfo{total perPage currentPage lastPage hasNextPage}media(id:$id,type:$type,season:$season,format_in:$format,status:$status,countryOfOrigin:$countryOfOrigin,source:$source,search:$search,onList:$onList,seasonYear:$seasonYear,startDate_like:$year,startDate_lesser:$yearLesser,startDate_greater:$yearGreater,episodes_lesser:$episodeLesser,episodes_greater:$episodeGreater,duration_lesser:$durationLesser,duration_greater:$durationGreater,chapters_lesser:$chapterLesser,chapters_greater:$chapterGreater,volumes_lesser:$volumeLesser,volumes_greater:$volumeGreater,licensedBy_in:$licensedBy,isLicensed:$isLicensed,genre_in:$genres,genre_not_in:$excludedGenres,tag_in:$tags,tag_not_in:$excludedTags,minimumTagRank:$minimumTagRank,sort:$sort,isAdult:$isAdult){id idMal isAdult status chapters episodes nextAiringEpisode{episode}type genres meanScore isFavourite format bannerImage coverImage{large extraLarge}title{english romaji userPreferred}mediaListEntry{progress private score(format:POINT_100)status}staff{edges{node{languageV2}}}}}}",
      "variables": {
        "page": page,
        "type": "ANIME",
        "isAdult": false,
        "sort": "POPULARITY_DESC",
      },
    };

    return HttpClient.post(
      "https://graphql.anilist.co",
      data: params,
    ).then(
      (res) => PageResult.fromJson(res.data["data"]["Page"]),
      onError: (e) => null,
    );
  }

  static Future<List<WeeklySearchResult>> weekly() async {
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();
    final future = now + 604800;

    Map<String, dynamic> makeParams(int page) => {
          "query":
              "{Page(page:$page,perPage:50){pageInfo{hasNextPage total}airingSchedules(airingAt_greater:$now airingAt_lesser:$future sort:TIME_DESC){episode airingAt media{id idMal status chapters episodes nextAiringEpisode{episode}isAdult type meanScore isFavourite format bannerImage countryOfOrigin coverImage{large}title{english romaji userPreferred}mediaListEntry{progress private score(format:POINT_100)status}}}}}",
        };

    final ret = <WeeklySearchResult>[];
    int page = 1;
    final seen = <int>{};

    try {
      var res = await http.post(
        Uri.parse("https://graphql.anilist.co"),
        body: makeParams(page),
      );
      var data = jsonDecode(res.body)["data"]["Page"];

      for (final item in data["airingSchedules"]) {
        if (item["media"]?["countryOfOrigin"] == "CN") {
          continue;
        }

        final w = WeeklySearchResult.fromJson(item);

        if (seen.contains(w.media.id)) {
          continue;
        }

        ret.add(w);
        seen.add(w.media.id);
      }

      while (data["pageInfo"]["hasNextPage"]) {
        res = await http.post(
          Uri.parse("https://graphql.anilist.co"),
          body: makeParams(++page),
        );
        data = jsonDecode(res.body)["data"]["Page"];

        for (final item in data["airingSchedules"]) {
          if (item["media"]?["countryOfOrigin"] == "CN") {
            continue;
          }

          final w = WeeklySearchResult.fromJson(item);

          if (seen.contains(w.media.id)) {
            continue;
          }

          ret.add(w);
          seen.add(w.media.id);
        }
      }
    } catch (e) {
      prints("Failed to get anime info: $e");
    }

    // Sort them by their airingAt date.
    ret.sort((a, b) => a.airingAt.compareTo(b.airingAt));

    return ret;
  }

  static Future<BrowseResult?> browse() async {
    final now = DateTime.now();
    final month = now.month;
    final seasonIndex = (month ~/ 3) % 4;
    final season = _seasons[seasonIndex];

    // Calculate next season/year. For example, we increment a year if we're in the last season of the year.
    final nextSeasonIndex = (seasonIndex + 1) % 4;
    final nextYear = now.year + ((seasonIndex + 1) ~/ 4);
    final nextSeason = _seasons[nextSeasonIndex];
    final nextSeasonYear = nextSeasonIndex == 0 ? nextYear + 1 : nextYear;

    final params = {
      "query":
          r"query($season:MediaSeason,$seasonYear:Int $nextSeason:MediaSeason,$nextYear:Int){trending:Page(page:1,perPage:10){media(sort:TRENDING_DESC,type:ANIME,isAdult:false){...media}}season:Page(page:1,perPage:10){media(season:$season,seasonYear:$seasonYear,sort:POPULARITY_DESC,type:ANIME,isAdult:false){...media}}nextSeason:Page(page:1,perPage:10){media(season:$nextSeason,seasonYear:$nextYear,sort:POPULARITY_DESC,type:ANIME,isAdult:false){...media}}popular:Page(page:1,perPage:10){media(sort:POPULARITY_DESC,type:ANIME,isAdult:false){...media}}top:Page(page:1,perPage:10){media(sort:SCORE_DESC,type:ANIME,isAdult:false){...media}}}fragment media on Media{id idMal title{english romaji userPreferred}coverImage{extraLarge large color}startDate{year month day}endDate{year month day}bannerImage season seasonYear description type format status(version:2)episodes duration chapters volumes genres meanScore isAdult averageScore popularity mediaListEntry{id status}nextAiringEpisode{airingAt timeUntilAiring episode}studios(isMain:true){edges{isMain node{id name}}}}",
      "variables": {
        "season": season,
        "seasonYear": now.year,
        "nextSeason": nextSeason,
        "nextYear": nextSeasonYear,
      },
    };

    try {
      final ret = await HttpClient.post(
        "https://graphql.anilist.co",
        data: params,
      ).then((res) => BrowseResult.fromJson(res.data["data"]));
      return ret;
    } catch (e) {
      prints("Failed to get anime info: $e");
      return null;
    }
  }

  static Future<GenresAndTags?> genresAndTags() async {
    final params = {
      "query":
          r"query{genres:GenreCollection tags:MediaTagCollection{name description category isAdult}}",
    };

    return HttpClient.post(
      "https://graphql.anilist.co",
      data: params,
    ).then((res) => GenresAndTags.fromJson(res.data["data"]));
  }

  static Future<PageResult?> popularSeason(
    int page, {
    DateTime? start,
  }) async {
    final now = start ?? DateTime.now();
    final month = now.month;
    final seasonIndex = (month ~/ 3) % 4;
    final season = _seasons[seasonIndex];

    final params = {
      "query":
          r"query($page:Int = 1 $id:Int $type:MediaType $isAdult:Boolean = false $search:String $format:[MediaFormat]$status:MediaStatus $countryOfOrigin:CountryCode $source:MediaSource $season:MediaSeason $seasonYear:Int $year:String $onList:Boolean $yearLesser:FuzzyDateInt $yearGreater:FuzzyDateInt $episodeLesser:Int $episodeGreater:Int $durationLesser:Int $durationGreater:Int $chapterLesser:Int $chapterGreater:Int $volumeLesser:Int $volumeGreater:Int $licensedBy:[Int]$isLicensed:Boolean $genres:[String]$excludedGenres:[String]$tags:[String]$excludedTags:[String]$minimumTagRank:Int $sort:[MediaSort]=[POPULARITY_DESC,SCORE_DESC]){Page(page:$page,perPage:20){pageInfo{total perPage currentPage lastPage hasNextPage}media(id:$id type:$type season:$season format_in:$format status:$status countryOfOrigin:$countryOfOrigin source:$source search:$search onList:$onList seasonYear:$seasonYear startDate_like:$year startDate_lesser:$yearLesser startDate_greater:$yearGreater episodes_lesser:$episodeLesser episodes_greater:$episodeGreater duration_lesser:$durationLesser duration_greater:$durationGreater chapters_lesser:$chapterLesser chapters_greater:$chapterGreater volumes_lesser:$volumeLesser volumes_greater:$volumeGreater licensedById_in:$licensedBy isLicensed:$isLicensed genre_in:$genres genre_not_in:$excludedGenres tag_in:$tags tag_not_in:$excludedTags minimumTagRank:$minimumTagRank sort:$sort isAdult:$isAdult){id title{english romaji userPreferred}coverImage{extraLarge large color}startDate{year month day}endDate{year month day}bannerImage season seasonYear description type format status(version:2)episodes duration chapters volumes genres isAdult averageScore popularity nextAiringEpisode{airingAt timeUntilAiring episode}mediaListEntry{id status}staff{edges{node{languageV2}}}studios(isMain:true){edges{isMain node{id name}}}}}}",
      "variables": {
        "page": page,
        "type": "ANIME",
        "seasonYear": now.year,
        "season": season,
      },
    };

    return HttpClient.post(
      "https://graphql.anilist.co",
      data: params,
    ).then(
      (res) => PageResult.fromJson(res.data["data"]["Page"]),
      onError: (e) => null,
    );
  }
}
