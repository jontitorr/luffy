import "dart:convert";

import "package:encrypt/encrypt.dart";
import "package:html/parser.dart";
import "package:http/http.dart" as http;
import "package:luffy/api/anime.dart";
import "package:luffy/util.dart";

(Encrypter, IV) _encrypt(String keyy, String ivv) {
  final key = Key.fromUtf8(keyy);
  final iv = IV.fromUtf8(ivv);
  final encrypter = Encrypter(
    AES(key, mode: AESMode.cbc),
  );
  return (encrypter, iv);
}

String cryptoHandler(
  String text,
  String iv,
  String secretKeyString,
  bool encrypt,
) {
  if (encrypt) {
    final encryptt = _encrypt(secretKeyString, iv);
    final en = encryptt.$1.encrypt(text, iv: encryptt.$2);
    return en.base64;
  } else {
    final encryptt = _encrypt(secretKeyString, iv);
    final en = encryptt.$1.decrypt64(text, iv: encryptt.$2);
    return en;
  }
}

Future<List<VideoSource>> gogoCdnExtractor(String url) async {
  final res = await http.get(Uri.parse(url));
  final document = parse(res.body);
  final iv = document
      .querySelector("div.wrapper")!
      .attributes["class"]!
      .split("container-")
      .last;
  final secretKey = document
      .querySelector("body[class]")!
      .attributes["class"]!
      .split("container-")
      .last;
  RegExp(r"container-(\d+)").firstMatch(res.body)?.group(1);
  final decryptionKey =
      RegExp(r"videocontent-(\d+)").firstMatch(res.body)?.group(1);
  final encryptAjaxParams = cryptoHandler(
    RegExp(r'data-value="([^"]+)').firstMatch(res.body)?.group(1) ?? "",
    iv,
    secretKey,
    false,
  ).substringAfter("&");
  final uri = Uri.parse(url);
  final host = "https://${uri.host}/";
  final id = uri.queryParameters["id"];
  final encryptedId = cryptoHandler(id ?? "", iv, secretKey, true);
  final token = uri.queryParameters["token"];
  final qualityPrefix = token != null ? "Gogostream - " : "Vidstreaming - ";
  final encryptAjaxUrl =
      "${host}encrypt-ajax.php?id=$encryptedId&$encryptAjaxParams&alias=$id";
  final encryptAjaxResponse = await http.get(
    Uri.parse(encryptAjaxUrl),
    headers: {"X-Requested-With": "XMLHttpRequest"},
  );
  final jsonResponse = encryptAjaxResponse.body;
  final data = jsonDecode(jsonResponse)["data"];
  final decryptedData = cryptoHandler(data ?? "", iv, decryptionKey!, false);
  final videoList = <VideoSource>[];
  final autoList = <VideoSource>[];
  final array = jsonDecode(decryptedData)["source"];

  try {
    if (array != null &&
        array is List &&
        array.length == 1 &&
        array[0]["type"] == "hls") {
      final fileURL = array[0]["file"].toString().trim();
      const separator = "#EXT-X-STREAM-INF:";
      final masterPlaylistResponse = await http.get(Uri.parse(fileURL));
      final masterPlaylist = masterPlaylistResponse.body;
      if (masterPlaylist.contains(separator)) {
        for (final it
            in masterPlaylist.substringAfter(separator).split(separator)) {
          final quality =
              "${it.substringAfter("RESOLUTION=").substringAfter("x").substringBefore(",").substringBefore("\n")}p";

          var videoUrl = it.substringAfter("\n").substringBefore("\n");

          if (!videoUrl.startsWith("http")) {
            videoUrl =
                "${fileURL.split("/").sublist(0, fileURL.split("/").length - 1).join("/")}/$videoUrl";
          }
          videoList.add(
            VideoSource(
              videoUrl: videoUrl,
              description: "$qualityPrefix$quality",
            ),
          );
        }
      } else {
        videoList.add(
          VideoSource(
            videoUrl: fileURL,
            description: "${qualityPrefix}Original",
          ),
        );
      }
    } else if (array != null && array is List) {
      for (final it in array) {
        final label =
            it["label"].toString().toLowerCase().trim().replaceAll(" ", "");
        final fileURL = it["file"].toString().trim();
        final videoHeaders = {"Referer": url};
        if (label == "auto") {
          autoList.add(
            VideoSource(
              videoUrl: fileURL,
              description: "$qualityPrefix$label",
              headers: videoHeaders,
            ),
          );
        } else {
          videoList.add(
            VideoSource(
              videoUrl: fileURL,
              description: "$qualityPrefix$label",
              headers: videoHeaders,
            ),
          );
        }
      }
    }
  } catch (e) {
    prints("Failed to extract gogoCdn: $e");
  }

  return videoList + autoList;
}
