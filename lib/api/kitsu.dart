import "package:luffy/http_client.dart";
import "package:luffy/util.dart";

class Episode {
  Episode({
    required this.number,
    required this.title,
    this.description,
    this.image,
  });

  Episode.fromJson(Map<String, dynamic> json)
      : number = json["number"],
        title = json["titles"]["canonical"],
        description = json["description"].runtimeType == String
            ? json["description"]
            : null,
        image = json["thumbnail"]?["original"]?["url"];

  final int number;
  final String title;
  final String? description;
  final String? image;
}

class KituService {
  static Future<List<Episode>> search(int animeId) async {
    final params = {
      "query":
          "query{lookupMapping(externalId:$animeId,externalSite:ANILIST_ANIME){__typename...on Anime{id episodes(first:2000){nodes{number titles{canonical}description thumbnail{original{url}}}}}}}",
    };

    try {
      final res = await HttpClient.post(
        "https://kitsu.io/api/graphql",
        data: params,
      );
      final data = res.data["data"]["lookupMapping"];
      final ret = <Episode>[];

      for (final episode in data["episodes"]["nodes"]) {
        if (episode == null) {
          continue;
        }

        ret.add(Episode.fromJson(episode));
      }

      return ret;
    } catch (e) {
      prints("Failed to get episodes: $e");
      return [];
    }
  }
}
