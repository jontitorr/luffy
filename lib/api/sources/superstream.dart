import "dart:convert";
import "dart:typed_data";

import "package:collection/collection.dart";
import "package:crypto/crypto.dart";
import "package:dart_des/dart_des.dart";
import "package:encrypt/encrypt.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/http_client.dart";
import "package:luffy/util.dart";
import "package:luffy/util/subtitle.dart" hide Subtitle;
import "package:pointycastle/export.dart";

final _key =
    Key.fromUtf8(utf8.decode(base64Decode("MTIzZDZjZWRmNjI2ZHk1NDIzM2FhMXc2")));
final _iv = IV.fromUtf8(utf8.decode(base64Decode("d0VpcGhUbiE=")));
final _apiUrl = utf8.decode(
  base64Decode(
    "aHR0cHM6Ly9zaG93Ym94LnNoZWd1Lm5ldC9hcGkvYXBpX2NsaWVudC9pbmRleC8=",
  ),
);
final _appKey = utf8.decode(base64Decode("bW92aWVib3g="));
final _appId = utf8.decode(base64Decode("Y29tLnRkby5zaG93Ym94"));
const _appVersion = "11.5";

String _randomToken() =>
    List.generate(32, (i) => ("0123456789abcdef".split("")..shuffle()).first)
        .join();

String? _encrypt(String str, String key, String iv) {
  try {
    final cipher = PaddedBlockCipher("DESede/CBC/PKCS5Padding");
    final keyParam = KeyParameter(Uint8List.fromList(utf8.encode(key)));
    cipher.init(
      true,
      ParametersWithIV(keyParam, Uint8List.fromList(utf8.encode(iv))),
    );

    final input = Uint8List.fromList(utf8.encode(str));
    final encrypted = cipher.process(input);

    return base64.encode(encrypted);
  } catch (e) {
    prints("Failed to encrypt: $e");
    return null;
  }
}

String? _decrypt(String encryptedStr, Key key, IV iv) {
  final encryptedBytes = base64Decode(encryptedStr);
  final decryptedBytes = DES3(
    key: key.bytes,
    mode: DESMode.CBC,
    iv: iv.bytes,
    paddingType: DESPaddingType.PKCS5,
  ).decrypt(encryptedBytes);

  return utf8.decode(decryptedBytes);
}

final _hexDigits = utf8.encode("0123456789ABCDEF");

String toHexString(List<int> bArr) {
  const i = 0;
  final i2 = bArr.length;
  final cArr = List.filled(i2 * 2, 0);
  var i3 = 0;

  for (var i4 = i; i4 < i + i2; i4++) {
    final b = bArr[i4];
    final i5 = i3 + 1;
    final cArr2 = _hexDigits;

    cArr[i3] = cArr2[(b >> 4) & 15];
    i3 = i5 + 1;
    cArr[i5] = cArr2[b & 15];
  }

  return String.fromCharCodes(cArr);
}

String _md5(String message) {
  final bytes = md5.convert(utf8.encode(message)).bytes;
  return toHexString(bytes).toLowerCase();
}

String? _getVerify(String? str, String str2, String str3) {
  if (str != null) {
    return _md5(_md5(str2) + str3 + str);
  }

  return null;
}

Future<dynamic> _queryApi(
  String query,
) async {
  final encrypted = _encrypt(query, _key.toString(), _iv.toString());
  final newBody = {
    "app_key": _md5(_appKey),
    "verify": _getVerify(encrypted, _appKey, utf8.decode(_key.bytes)),
    "encrypt_data": encrypted,
  };
  final base64Encoded = base64Encode(utf8.encode(jsonEncode(newBody)));
  final data = {
    "data": base64Encoded,
    "appId": "27",
    "platform": "android",
    "version": "129",
    "medium": "Website&token${_randomToken()}",
  };

  try {
    final res = await HttpClient.post(
      _apiUrl,
      headers: {
        "Platform": "android",
        "Accept": "charset=utf-8",
        "Content-Type": "application/x-www-form-urlencoded",
      },
      data: data,
    );

    if (res.statusCode == 200) {
      return res.data["data"];
    }
  } catch (e) {
    prints(e);
  }

  return null;
}

int _getExpiryDate() {
  return DateTime.now().add(const Duration(hours: 12)).millisecondsSinceEpoch;
}

class Media {
  Media.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        mid = json["mid"],
        boxType = json["box_type"],
        title = json["title"],
        posterOrg = json["poster_org"],
        cats = json["cats"],
        year = json["year"],
        imdbRating = json["imdb_rating"],
        qualityTag = json["quality_tag"];

  final int? id;
  final int? mid;
  final int? boxType;
  final String? title;
  final String? posterOrg;
  final String? cats;
  final int? year;
  final String? imdbRating;
  final String? qualityTag;

  Map<String, dynamic> toJson() => {
        "id": id,
        "mid": mid,
        "box_type": boxType,
        "title": title,
        "poster_org": posterOrg,
        "cats": cats,
        "year": year,
        "imdb_rating": imdbRating,
        "quality_tag": qualityTag,
      };
}

class MediaType {
  static const int movie = 1;
  static const int series = 2;
}

class Movie {
  Movie.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        title = json["title"],
        director = json["director"],
        writer = json["writer"],
        actors = json["actors"],
        runtime = json["runtime"],
        poster = json["poster"],
        description = json["description"],
        cats = json["cats"],
        year = json["year"],
        imdbId = json["imdb_id"],
        imdbRating = json["imdb_rating"],
        trailer = json["trailer"],
        released = json["released"],
        contentRating = json["content_rating"],
        tmdbId = json["tmdb_id"],
        tomatoMeter = json["tomato_meter"],
        posterOrg = json["poster_org"],
        trailerUrl = json["trailer_url"],
        imdbLink = json["imdb_link"],
        boxType = json["box_type"],
        recommend = json["recommend"] != null
            ? List<Media>.from(
                json["recommend"].map((x) => Media.fromJson(x)),
              )
            : [];

  final int? id;
  final String? title;
  final String? director;
  final String? writer;
  final String? actors;
  final int? runtime;
  final String? poster;
  final String? description;
  final String? cats;
  final int? year;
  final String? imdbId;
  final String? imdbRating;
  final String? trailer;
  final String? released;
  final String? contentRating;
  final int? tmdbId;
  final int? tomatoMeter;
  final String? posterOrg;
  final String? trailerUrl;
  final String? imdbLink;
  final int? boxType;
  final List<Media> recommend;
}

class SeriesEpisode {
  SeriesEpisode({
    this.id,
    this.tid,
    this.mbId,
    this.imdbId,
    this.imdbIdStatus,
    this.srtStatus,
    this.season,
    this.episode,
    this.state,
    this.title,
    this.thumbs,
    this.thumbsBak,
    this.thumbsOriginal,
    this.posterImdb,
    this.synopsis,
    this.runtime,
    this.view,
    this.download,
    this.sourceFile,
    this.codeFile,
    this.addTime,
    this.updateTime,
    this.released,
    this.releasedTimestamp,
    this.audioLang,
    this.qualityTag,
    this.threeD,
    this.remark,
    this.pending,
    this.imdbRating,
    this.display,
    this.sync,
    this.tomatoMeter,
    this.tomatoMeterCount,
    this.tomatoAudience,
    this.tomatoAudienceCount,
    this.thumbsMin,
    this.thumbsOrg,
    this.imdbLink,
  });

  SeriesEpisode.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        tid = json["tid"],
        mbId = json["mb_id"],
        imdbId = json["imdb_id"],
        imdbIdStatus = json["imdb_id_status"],
        srtStatus = json["srt_status"],
        season = json["season"],
        episode = json["episode"],
        state = json["state"],
        title = json["title"],
        thumbs = json["thumbs"],
        thumbsBak = json["thumbs_bak"],
        thumbsOriginal = json["thumbs_original"],
        posterImdb = json["poster_imdb"],
        synopsis = json["synopsis"],
        runtime = json["runtime"],
        view = json["view"],
        download = json["download"],
        sourceFile = json["source_file"],
        codeFile = json["code_file"],
        addTime = json["add_time"],
        updateTime = json["update_time"],
        released = json["released"],
        releasedTimestamp = json["released_timestamp"],
        audioLang = json["audio_lang"],
        qualityTag = json["quality_tag"],
        threeD = json["3d"],
        remark = json["remark"],
        pending = json["pending"],
        imdbRating = json["imdb_rating"],
        display = json["display"],
        sync = json["sync"],
        tomatoMeter = json["tomato_meter"],
        tomatoMeterCount = json["tomato_meter_count"],
        tomatoAudience = json["tomato_audience"],
        tomatoAudienceCount = json["tomato_audience_count"],
        thumbsMin = json["thumbs_min"],
        thumbsOrg = json["thumbs_org"],
        imdbLink = json["imdb_link"];

  final int? id;
  final int? tid;
  final int? mbId;
  final String? imdbId;
  final int? imdbIdStatus;
  final int? srtStatus;
  final int? season;
  final int? episode;
  final int? state;
  final String? title;
  final String? thumbs;
  final String? thumbsBak;
  final String? thumbsOriginal;
  final int? posterImdb;
  final String? synopsis;
  final int? runtime;
  final int? view;
  final int? download;
  final int? sourceFile;
  final int? codeFile;
  final int? addTime;
  final int? updateTime;
  final String? released;
  final int? releasedTimestamp;
  final String? audioLang;
  final String? qualityTag;
  final int? threeD;
  final String? remark;
  final String? pending;
  final String? imdbRating;
  final int? display;
  final int? sync;
  final int? tomatoMeter;
  final int? tomatoMeterCount;
  final int? tomatoAudience;
  final int? tomatoAudienceCount;
  final String? thumbsMin;
  final String? thumbsOrg;
  final String? imdbLink;
}

class SeriesLanguage {
  SeriesLanguage.fromJson(Map<String, dynamic> json)
      : title = json["title"],
        lang = json["lang"];

  final String? title;
  final String? lang;
}

class LinkData {
  LinkData({
    required this.id,
    required this.type,
    required this.season,
    required this.episode,
  });

  LinkData.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        type = json["type"],
        season = json["season"],
        episode = json["episode"];

  final int? id;
  final int? type;
  final int? season;
  final int? episode;

  Map<String, dynamic> toJson() => {
        "id": id,
        "type": type,
        "season": season,
        "episode": episode,
      };
}

class LinkList {
  LinkList.fromJson(Map<String, dynamic> json)
      : path = json["path"],
        quality = json["quality"],
        realQuality = json["real_quality"],
        format = json["format"],
        size = json["size"],
        sizeBytes = json["size_bytes"],
        count = json["count"],
        dateline = json["dateline"],
        fid = json["fid"],
        mmfid = json["mmfid"],
        h265 = json["h265"],
        hdr = json["hdr"],
        filename = json["filename"],
        original = json["original"],
        colorbit = json["colorbit"],
        success = json["success"],
        timeout = json["timeout"],
        vipLink = json["vip_link"],
        fps = json["fps"],
        bitstream = json["bitstream"],
        width = json["width"],
        height = json["height"];

  final String? path;
  final String? quality;
  final String? realQuality;
  final String? format;
  final String? size;
  final int? sizeBytes;
  final int? count;
  final int? dateline;
  final int? fid;
  final int? mmfid;
  final int? h265;
  final int? hdr;
  final String? filename;
  final int? original;
  final int? colorbit;
  final int? success;
  final int? timeout;
  final int? vipLink;
  final int? fps;
  final String? bitstream;
  final int? width;
  final int? height;
}

class ParsedLinkData {
  ParsedLinkData.fromJson(Map<String, dynamic> json)
      : seconds = json["seconds"],
        quality = List<String>.from(
          json["quality"].map((x) => x),
        ),
        list = json["list"] != null
            ? List<LinkList>.from(
                json["list"].map((x) => LinkList.fromJson(x)),
              )
            : [];

  final int? seconds;
  final List<String> quality;
  final List<LinkList> list;
}

class PrivateSubtitleData {
  PrivateSubtitleData.fromJson(Map<String, dynamic> json)
      : select = json["select"] != null
            ? List<String>.from(
                json["select"].map((x) => x),
              )
            : [],
        list = json["list"] != null
            ? List<SubtitleList>.from(
                json["list"].map((x) => SubtitleList.fromJson(x)),
              )
            : [];

  final List<String> select;
  final List<SubtitleList> list;
}

class SubtitleList {
  SubtitleList.fromJson(Map<String, dynamic> json)
      : language = json["language"],
        subtitles = json["subtitles"] != null
            ? List<Subtitles>.from(
                json["subtitles"].map((x) => Subtitles.fromJson(x)),
              )
            : [];

  final String? language;
  final List<Subtitles> subtitles;
}

class Subtitles {
  Subtitles.fromJson(Map<String, dynamic> json)
      : sid = json["sid"],
        mid = json["mid"],
        filePath = json["file_path"],
        lang = json["lang"],
        language = json["language"],
        delay = json["delay"],
        point = json["point"].toString(), // It can be an int
        order = json["order"],
        adminOrder = json["admin_order"],
        myselect = json["myselect"],
        addTime = json["add_time"],
        count = json["count"];

  final int? sid;
  final String? mid;
  final String? filePath;
  final String? lang;
  final String? language;
  final int? delay;
  final String? point;
  final int? order;
  final int? adminOrder;
  final int? myselect;
  final int? addTime;
  final int? count;
}

class SeriesData {
  SeriesData.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        mbId = json["mb_id"],
        title = json["title"],
        display = json["display"],
        state = json["state"],
        vipOnly = json["vip_only"],
        codeFile = json["code_file"],
        director = json["director"],
        writer = json["writer"],
        actors = json["actors"],
        addTime = json["add_time"],
        poster = json["poster"],
        posterImdb = json["poster_imdb"],
        bannerMini = json["banner_mini"],
        description = json["description"],
        imdbId = json["imdb_id"],
        cats = json["cats"],
        year = json["year"],
        collect = json["collect"],
        view = json["view"],
        download = json["download"],
        updateTime = json["update_time"].runtimeType == int
            ? DateTime.fromMillisecondsSinceEpoch(json["update_time"] * 1000)
            : DateTime.parse(json["update_time"]),
        released = json["released"],
        releasedTimestamp = json["released_timestamp"],
        episodeReleased = json["episode_released"],
        episodeReleasedTimestamp = json["episode_released_timestamp"],
        maxSeason = json["max_season"],
        maxEpisode = json["max_episode"],
        remark = json["remark"],
        imdbRating = json["imdb_rating"],
        contentRating = json["content_rating"],
        tmdbId = json["tmdb_id"],
        tomatoUrl = json["tomato_url"],
        tomatoMeter = json["tomato_meter"],
        tomatoMeterCount = json["tomato_meter_count"],
        tomatoMeterState = json["tomato_meter_state"],
        reelgoodUrl = json["reelgood_url"],
        audienceScore = json["audience_score"],
        audienceScoreCount = json["audience_score_count"],
        noTomatoUrl = json["no_tomato_url"],
        orderYear = json["order_year"],
        episodateId = json["episodate_id"],
        weightsDay = json["weights_day"],
        posterMin = json["poster_min"],
        posterOrg = json["poster_org"],
        bannerMiniMin = json["banner_mini_min"],
        bannerMiniOrg = json["banner_mini_org"],
        trailerUrl = json["trailer_url"],
        years = List<int>.from(json["years"] ?? []),
        season = List<int>.from(json["season"] ?? []),
        history = List<String>.from(json["history"] ?? []),
        imdbLink = json["imdb_link"],
        episode = (json["episode"] as List<dynamic>?)
                ?.map((e) => SeriesEpisode.fromJson(e))
                .toList() ??
            [],
        language = (json["language"] as List<dynamic>?)
                ?.map((e) => SeriesLanguage.fromJson(e))
                .toList() ??
            [],
        boxType = json["box_type"],
        yearYear = json["year_year"],
        seasonEpisode = json["season_episode"];
  final int? id;
  final int? mbId;
  final String? title;
  final int? display;
  final int? state;
  final int? vipOnly;
  final int? codeFile;
  final String? director;
  final String? writer;
  final String? actors;
  final int? addTime;
  final String? poster;
  final int? posterImdb;
  final String? bannerMini;
  final String? description;
  final String? imdbId;
  final String? cats;
  final int? year;
  final int? collect;
  final int? view;
  final int? download;
  final DateTime? updateTime;
  final String? released;
  final int? releasedTimestamp;
  final String? episodeReleased;
  final int? episodeReleasedTimestamp;
  final int? maxSeason;
  final int? maxEpisode;
  final String? remark;
  final String? imdbRating;
  final String? contentRating;
  final int? tmdbId;
  final String? tomatoUrl;
  final int? tomatoMeter;
  final int? tomatoMeterCount;
  final String? tomatoMeterState;
  final String? reelgoodUrl;
  final int? audienceScore;
  final int? audienceScoreCount;
  final int? noTomatoUrl;
  final int? orderYear;
  final String? episodateId;
  final double? weightsDay;
  final String? posterMin;
  final String? posterOrg;
  final String? bannerMiniMin;
  final String? bannerMiniOrg;
  final String? trailerUrl;
  final List<int> years;
  final List<int> season;
  final List<String> history;
  final String? imdbLink;
  final List<SeriesEpisode> episode;
  final List<SeriesLanguage> language;
  final int? boxType;
  final String? yearYear;
  final String? seasonEpisode;
}

class Data {
  Data.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        mid = json["mid"],
        boxType = json["box_type"],
        title = json["title"],
        posterOrg = json["poster_org"],
        poster = json["poster"],
        cats = json["cats"],
        year = json["year"],
        imdbRating = json["imdb_rating"],
        qualityTag = json["quality_tag"];

  final int? id;
  final int? mid;
  final int? boxType;
  final String? title;
  final String? posterOrg;
  final String? poster;
  final String? cats;
  final int? year;
  final String? imdbRating;
  final String? qualityTag;
}

class MovieData {
  MovieData.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        title = json["title"],
        director = json["director"],
        writer = json["writer"],
        actors = json["actors"],
        runtime = json["runtime"],
        poster = json["poster"],
        description = json["description"],
        cats = json["cats"],
        year = json["year"],
        imdbId = json["imdb_id"],
        imdbRating = json["imdb_rating"],
        trailer = json["trailer"],
        released = json["released"],
        contentRating = json["content_rating"],
        tmdbId = json["tmdb_id"],
        tomatoMeter = json["tomato_meter"],
        posterOrg = json["poster_org"],
        trailerUrl = json["trailer_url"],
        imdbLink = json["imdb_link"],
        boxType = json["box_type"],
        recommend = (json["recommend"] as List<dynamic>?)
                ?.map((e) => Data.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

  final int? id;
  final String? title;
  final String? director;
  final String? writer;
  final String? actors;
  final int? runtime;
  final String? poster;
  final String? description;
  final String? cats;
  final int? year;
  final String? imdbId;
  final String? imdbRating;
  final String? trailer;
  final String? released;
  final String? contentRating;
  final int? tmdbId;
  final int? tomatoMeter;
  final String? posterOrg;
  final String? trailerUrl;
  final String? imdbLink;
  final int? boxType;
  final List<Data> recommend;
}

class _SuperStream {
  static Future<List<Media>> search(String query) async {
    query = query.toLowerCase().replaceAll('"', "");

    final apiQuery =
        """{"childmode":"1","app_version":"$_appVersion","appid":"$_appId","module":"Search3","channel":"Website","page":"1","lang":"en","type":"all","keyword":"$query","pagelimit":"20","expired_date":"${_getExpiryDate()}","platform":"android"}""";

    final results = await _queryApi(apiQuery);

    if (results != null) {
      return List<Media>.from(
        results.map((x) => Media.fromJson(x)),
      );
    }

    return [];
  }

  static Future<Map<String, dynamic>?> getInfo(Media media) async {
    final isMovie = media.boxType == MediaType.movie;

    final apiQuery = isMovie
        ? """{"childmode":"0","uid":"","app_version":"$_appVersion","appid":"$_appId","module":"Movie_detail","channel":"Website","mid":"${media.id}","lang":"en","expired_date":"${_getExpiryDate()}","platform":"android","oss":"","group":""}"""
        : """{"childmode":"0","uid":"","app_version":"$_appVersion","appid":"$_appId","module":"TV_detail_1","display_all":"1","channel":"Website","lang":"en","expired_date":"${_getExpiryDate()}","platform":"android","tid":"${media.id}"}""";

    return await _queryApi(apiQuery);
  }

  static Future<List<SeriesEpisode>> getEpisodes(SeriesData series) async {
    final ret = <SeriesEpisode>[];

    for (final it in series.season) {
      final apiQuery =
          """{"childmode":"0","app_version":"$_appVersion","year":"0","appid":"$_appId","module":"TV_episode","display_all":"1","channel":"Website","season":"$it","lang":"en","expired_date":"${_getExpiryDate()}","platform":"android","tid":"${series.id}"}""";
      final results = await _queryApi(apiQuery);

      if (results == null) {
        continue;
      }

      ret.addAll(
        List<SeriesEpisode>.from(
          results.map((x) => SeriesEpisode.fromJson(x)),
        ),
      );
    }

    return ret;
  }

  static Future<VideoSource?> getSeriesEpisodeVideoUrl(
    LinkData data,
  ) async {
    if (data.id == null) {
      return null;
    }

    final isMovie = data.type == MediaType.movie;

    final query = (() {
      if (isMovie) {
        return """{"childmode":"0","uid":"","app_version":"11.5","appid":"$_appId","module":"Movie_downloadurl_v3","channel":"Website","mid":"${data.id}","lang":"","expired_date":"${_getExpiryDate()}","platform":"android","oss":"1","group":""}""";
      }

      if (data.episode == null || data.season == null) {
        return null;
      }

      return """{"childmode":"0","app_version":"11.5","module":"TV_downloadurl_v3","channel":"Website","episode":"${data.episode}","expired_date":"${_getExpiryDate()}","platform":"android","tid":"${data.id}","oss":"1","uid":"","appid":"$_appId","season":"${data.season}","lang":"en","group":""}""";
    })();

    if (query == null) {
      return null;
    }

    final linkDataJson = await _queryApi(query);

    final linkData = ParsedLinkData.fromJson(
      linkDataJson,
    );

    final sources = linkData.list;

    if (sources.isEmpty) {
      return null;
    }

    final source = sources.firstWhereOrNull(
      (x) => x.path != null && x.path!.isNotEmpty,
    );

    final description =
        "${formatBytes(source?.sizeBytes ?? 0, 2)} ${source?.quality}";

    final path = source?.path?.replaceAll(r"\/", "");

    if (path == null) {
      return null;
    }

    // Look for subtitles.
    final fid =
        linkData.list.firstWhereOrNull((element) => element.fid != null)?.fid;

    if (fid == null) {
      return VideoSource(
        videoUrl: path,
        description: description,
      );
    }

    final subtitleQuery = isMovie
        ? """{"childmode":"0","fid":"$fid","uid":"","app_version":"11.5","appid":"$_appId","module":"Movie_srt_list_v2","channel":"Website","mid":"${data.id}","lang":"en","expired_date":"${_getExpiryDate()}","platform":"android"}"""
        : """{"childmode":"0","fid":"$fid","app_version":"11.5","module":"TV_srt_list_v2","channel":"Website","episode":"${data.episode}","expired_date":"${_getExpiryDate()}","platform":"android","tid":"${data.id}","uid":"","appid":"$_appId","season":"${data.season}","lang":"en"}""";

    final subtitlesJson = await _queryApi(subtitleQuery);

    final subtitles = PrivateSubtitleData.fromJson(
      subtitlesJson,
    ).list;

    if (subtitles.isEmpty) {
      return VideoSource(
        videoUrl: path,
        description: description,
      );
    }

    for (final subtitle in subtitles) {
      final subs = subtitle.subtitles;

      if (subs.isEmpty) {
        continue;
      }

      for (final sub in subs) {
        final lang = sub.lang;
        final filePath = sub.filePath;

        if (lang == null || filePath == null) {
          continue;
        }

        try {
          final res = await http.get(Uri.parse(filePath));

          if (res.statusCode != 200 || res.body.isEmpty) {
            continue;
          }

          final text = utf8.decode(res.bodyBytes);

          return VideoSource(
            videoUrl: path,
            description: description,
            subtitle: Subtitle(text: text, format: SubtitleFormat.srt),
          );
        } catch (e) {
          continue;
        }
      }
    }

    return VideoSource(
      videoUrl: path,
      description: description,
    );
  }
}

class SuperStream extends AnimeSource {
  @override
  String get name => "SuperStream";

  @override
  Future<List<Anime>> search(String query) async {
    final results = await _SuperStream.search(query);

    return List.from(
      results.map(
        (x) => Anime(
          imageUrl: x.posterOrg,
          title: x.title!,
          url: jsonEncode(x.toJson()),
        ),
      ),
    );
  }

  @override
  Future<List<Episode>> getEpisodes(Anime anime) async {
    final media = Media.fromJson(
      jsonDecode(anime.url),
    );

    final moreInfoData = await _SuperStream.getInfo(
      media,
    );

    if (moreInfoData == null) {
      return [];
    }

    final mediaType = moreInfoData["box_type"] as int? ?? media.boxType;
    final isMovie = media.boxType == MediaType.movie;

    if (isMovie) {
      final data = MovieData.fromJson(moreInfoData);
      final rating = double.tryParse(data.imdbRating ?? "");

      return [
        Episode(
          title: data.title,
          url: jsonEncode(
            LinkData(
              id: data.id,
              type: mediaType,
              season: 1,
              episode: 1,
            ).toJson(),
          ),
          thumbnailUrl: data.posterOrg,
          rating: rating != null ? (rating * 10.0).truncate() : null,
        ),
      ];
    }

    final data = SeriesData.fromJson(moreInfoData);
    final episodes = await _SuperStream.getEpisodes(data);
    final ret = <Episode>[];

    for (final episode in episodes) {
      final rating = double.tryParse(episode.imdbRating ?? "");

      ret.add(
        Episode(
          title: episode.title,
          url: jsonEncode(
            LinkData(
              id: episode.tid ?? episode.id,
              type: mediaType,
              season: episode.season,
              episode: episode.episode,
            ).toJson(),
          ),
          thumbnailUrl: episode.thumbs,
          rating: rating != null ? (rating * 10.0).truncate() : null,
          synopsis: episode.synopsis,
        ),
      );
    }

    return ret;
  }

  @override
  Future<List<VideoSource>> getSources(Episode episode) async {
    final source = await _SuperStream.getSeriesEpisodeVideoUrl(
      LinkData.fromJson(jsonDecode(episode.url)),
    );

    return source != null ? [source] : [];
  }
}
