import "dart:async";

import "package:luffy/api/anime.dart";
import "package:luffy/http_client.dart";
import "package:luffy/util.dart";
import "package:luffy/util/subtitle.dart" hide Subtitle;

const _baseUrl = "https://allanime.to";

String _bytesInHumanReadable(int bytes) {
  const kilobyte = 1000;
  const megabyte = kilobyte * 1000;
  const gigabyte = megabyte * 1000;
  const terabyte = gigabyte * 1000;

  if (bytes < kilobyte) {
    return "$bytes b/s";
  } else if (bytes < megabyte) {
    return "${bytes / kilobyte} kb/s";
  } else if (bytes < gigabyte) {
    return "${bytes / megabyte} mb/s";
  } else if (bytes < terabyte) {
    return "${bytes / gigabyte} gb/s";
  } else {
    return "${bytes / terabyte} tb/s";
  }
}

Future<List<VideoSource>> allanimeExtractor(
  String url,
  String name,
) async {
  try {
    final ret = <VideoSource>[];
    final endpoint = (await HttpClient.get("$_baseUrl/getVersion"))
        .data["episodeIframeHead"];
    var res = await HttpClient.get(
      "$endpoint${url.replaceFirst("/clock?", "/clock.json?")}",
    );

    for (final link in res.data["links"]) {
      if (link["link"] == null) {
        continue;
      }

      final subtitles = <Subtitle>[];
      final Map<String, String> headers = {
        "Accept": "*/*",
        "Host": Uri.parse(link["link"]).host,
        "Origin": endpoint,
        "Referer": "$endpoint/",
      };

      if (!(link["subtitles"]?.isEmpty ?? true)) {
        subtitles.addAll(
          link["subtitles"]
              .map((subtitle) async {
                String? text;

                try {
                  text = (await HttpClient.get(subtitle["src"])).data;
                } catch (e) {
                  prints("Failed to get subtitle: $e");
                }

                if (text == null) {
                  return null;
                }

                return Subtitle(
                  text: text,
                  format: SubtitleFormat.srt,
                );
              })
              .whereType<Subtitle>()
              .toList(),
        );
      }

      if ((link["mp4"] ?? false) == true) {
        ret.add(
          VideoSource(
            videoUrl: link["link"],
            description: "Original ($name - ${link["resolutionStr"]})",
            subtitle: subtitles.firstOrNull,
          ),
        );
      } else if ((link["hls"] ?? false) == true) {
        res = await HttpClient.get(link["link"], headers: headers);

        final String masterPlaylist = res.data;

        if (!masterPlaylist.contains("#EXT-X-STREAM-INF:")) {
          return [
            VideoSource(
              videoUrl: link["link"],
              description: "$name - ${link["resolutionStr"]}",
              headers: headers,
            ),
          ];
        }

        masterPlaylist
            .substringAfter("#EXT-X-STREAM-INF:")
            .split("#EXT-X-STREAM-INF:")
            .forEach((it) {
          final bandwidth = it.contains("AVERAGE-BANDWIDTH")
              ? " ${_bytesInHumanReadable(it.substringAfter("AVERAGE-BANDWIDTH=").substringBefore(",").toInt())}"
              : "";
          final quality =
              "${it.substringAfter("RESOLUTION=").substringAfter("x").substringBefore(",")}p$bandwidth ($name - ${link["resolutionStr"]})";
          var videoUrl = it.substringAfter("\n").substringBefore("\n");

          if (!videoUrl.startsWith("http")) {
            videoUrl =
                "${res.requestOptions.uri.toString().substringBeforeLast("/")}/$videoUrl";
          }

          ret.add(
            VideoSource(
              videoUrl: videoUrl,
              description: quality,
              headers: {
                "Accept": "*/*",
                "Host": Uri.parse(videoUrl).host,
                "Origin": endpoint,
                "Referer": "$endpoint/",
              },
            ),
          );
        });
      }
    }

    return ret;
  } catch (e) {
    prints("Failed to extract allanime: $e");
    return [];
  }
}
