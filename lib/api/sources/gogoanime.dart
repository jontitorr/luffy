import "package:collection/collection.dart";
import "package:html/parser.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/api/extractors/dood.dart";
import "package:luffy/api/extractors/gogocdn.dart";
import "package:luffy/api/extractors/mp4upload.dart";
import "package:luffy/api/extractors/streamwish.dart";
import "package:luffy/util.dart";

const _baseUrl = "https://anitaku.to";

class GogoAnime extends AnimeSource {
  @override
  String get name => "GogoAnime";

  @override
  Future<List<Anime>> search(String query) async {
    final encoded = Uri.encodeComponent(query);

    final res = await http.get(
      Uri.parse("$_baseUrl/search.html?keyword=$encoded"),
      headers: {
        "x-requested-with": "XMLHttpRequest",
      },
    );

    final root = parse(res.body);
    final ret = <Anime>[];
    final aTags = root.querySelectorAll("a");
    final divs = root.querySelectorAll(".thumbnail-recent_search");

    for (final pairs in IterableZip([aTags, divs])) {
      final title = pairs[0].attributes["title"];
      final href = pairs[0].attributes["href"];
      final img = pairs[1].attributes["style"];

      final regExp = RegExp(r"url\('(.+?)'\)");
      final imageUrl = regExp.firstMatch(img ?? "")?.group(1);

      if (title == null || href == null || imageUrl == null) {
        continue;
      }

      ret.add(
        Anime(
          title: title,
          url: "$_baseUrl$href",
          imageUrl: imageUrl,
        ),
      );
    }

    return ret;
  }

  @override
  Future<List<Episode>> getEpisodes(Anime anime) async {
    final res = await http.get(
      Uri.parse(anime.url),
      headers: {
        "x-requested-with": "XMLHttpRequest",
      },
    );

    final root = parse(res.body);
    final ret = <Episode>[];
    final animeId = root
        .querySelector("input#movie_id")
        ?.attributes["value"]
        ?.replaceAll(" ", "")
        .replaceAll("\n", "");

    if (animeId == null) {
      return ret;
    }

    final lis = root.querySelector("#episode_page")?.querySelectorAll("li");

    if (lis == null) {
      return ret;
    }

    final lastEpisode = lis.last.querySelector("a")?.attributes["ep_end"];

    if (lastEpisode == null) {
      return ret;
    }

    final res2 = await http.get(
      Uri.parse(
        "https://ajax.gogocdn.net/ajax/load-list-episode?ep_start=0&ep_end=$lastEpisode&id=$animeId",
      ),
      headers: {
        "Referer": "https://anitaku.to/",
      },
    );

    final root2 = parse(res2.body);
    final episodes = root2.querySelector("ul")?.querySelectorAll("li");

    if (episodes == null) {
      return ret;
    }

    // Episodes come in reverse order
    for (final episode in episodes.reversed) {
      final a = episode.querySelector("a");
      final title = a?.querySelector(".name")?.text;
      final href = a?.attributes["href"]?.trim();

      if (href == null) {
        continue;
      }

      ret.add(
        Episode(
          title: title,
          url: "$_baseUrl$href",
        ),
      );
    }

    return ret;
  }

  @override
  Future<List<VideoSource>> getSources(Episode episode) async {
    Future<http.Response> req(String url) {
      return http.get(
        Uri.parse(url),
        headers: {
          "x-requested-with": "XMLHttpRequest",
        },
      );
    }

    final res = await req(episode.url);
    final document = parse(res.body);
    final serverElements = document
            .querySelector(".anime_muti_link")
            ?.querySelector("ul")
            ?.querySelectorAll("li")
            .toList() ??
        [];
    final serverUrls = serverElements
        .map((e) => e.querySelector("a")?.attributes["data-video"])
        .whereNotNull()
        .toList();
    final serverNames = serverElements.map((e) => e.classes.first).toList();
    final ret = <VideoSource>[];

    for (final pair in IterableZip([serverNames, serverUrls])) {
      final name = pair[0];
      final url = pair[1];

      if (name.contains("anime") || name.contains("vidcdn")) {
        ret.addAll(await gogoCdnExtractor(url));
      } else if (name.contains("doodstream")) {
        ret.addAll(await doodExtractor(url));
      } else if (name.contains("mp4upload")) {
        ret.addAll(await mp4UploadExtractor(url));
      } else if (name.contains("filelions")) {
        ret.addAll(await streamWishExtractor(url, "FileLions"));
      } else if (name.contains("streamwish")) {
        ret.addAll(await streamWishExtractor(url, "StreamWish"));
      }
    }

    final seen = <String>{};
    ret.retainWhere((element) => seen.add(element.videoUrl));

    prints("Found sources for ${episode.title}: ${ret.length} sources:");
    for (final source in ret) {
      prints("\t${source.description} (${source.videoUrl})");
    }

    return ret;
  }
}
