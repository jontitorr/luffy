import "dart:convert";
import "dart:math";

import "package:html/parser.dart";
import "package:http/http.dart" as http;
import "package:luffy/http_client.dart";
import "package:luffy/js_unpacker.dart";
import "package:luffy/util.dart";

Future<String?> getHlsStreamUrl(String kwikUrl, String referer) async {
  return parse(
    (await HttpClient.get(kwikUrl, headers: {"referer": referer}))
        .data
        .toString(),
  )
      .querySelectorAll("script")
      .where(
        (script) => script.text.contains("eval"),
      )
      .firstOrNull
      ?.text
      .substringAfterLast("eval(function(")
      .let(
        (script) => JsUnpacker.unpackAndCombine("eval(function($script)").let(
          (unpacked) =>
              unpacked.substringAfter("const source='").substringBefore("';"),
        ),
      );
}

Future<String?> getStreamUrlFromKwik(String paheUrl) async {
  final res = await (await HttpClient.get("$paheUrl/i", followRedirects: false))
      .headers
      .value("location")
      ?.substringAfterLast("https://")
      .let(
        (kwikUrl) => HttpClient.get(
          "https://$kwikUrl",
          headers: {"referer": "https://kwik.cx/"},
        ),
      );
  final cookies = res?.headers["set-cookie"];

  if (res == null || cookies == null) {
    return null;
  }

  final body = res.data.toString();
  final kwikParamsRegex = RegExp(r'\("(\w+)",\d+,"(\w+)",(\d+),(\d+),\d+\)');
  final kwikDUrl = RegExp(r'action="([^"]+)"');
  final kwikDToken = RegExp(r'value="([^"]+)"');

  final match = kwikParamsRegex.firstMatch(body);

  if (match == null || match.groupCount != 4) {
    return null;
  }

  final [fullString, key, v1, v2] = match.groups([1, 2, 3, 4]);
  final decrypted = decrypt(fullString!, key!, int.parse(v1!), int.parse(v2!));
  final uri = kwikDUrl.firstMatch(decrypted)?.group(1);
  final tok = kwikDToken.firstMatch(decrypted)?.group(1);

  if (uri == null || tok == null) {
    return null;
  }

  final client = http.Client();
  http.Response? content;

  var code = 419;
  var tries = 0;

  while (code != 302 && tries < 20) {
    try {
      final req = http.Request("POST", Uri.parse(uri));
      req.headers["content-type"] = "application/x-www-form-urlencoded";
      req.headers["cookie"] =
          cookies.map((cookie) => cookie.replaceAll("path=/;", "")).join(";");
      req.bodyBytes = utf8.encode(Uri(queryParameters: {"_token": tok}).query);
      req.headers["referer"] = res.requestOptions.uri.toString();

      content = await http.Response.fromStream(await client.send(req));
      code = content.statusCode;
    } catch (e) {
      prints("Failed to get stream url: $e");
    } finally {
      ++tries;
    }
  }

  if (tries > 19) {
    return null;
  }

  return content?.headers["location"];
}

String decrypt(String fullString, String key, int v1, int v2) {
  var r = "";
  var i = 0;

  while (i < fullString.length) {
    var s = "";

    while (fullString[i] != key[v2]) {
      s += fullString[i];
      ++i;
    }
    var j = 0;

    while (j < key.length) {
      s = s.replaceAll(key[j], j.toString());
      ++j;
    }
    r += (getString(s, v2).toInt() - v1).toChar();
    ++i;
  }
  return r;
}

String getString(String content, int s1) {
  const characterMap =
      "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ+/";
  final slice2 = characterMap.substring(0, 10);
  var acc = 0;

  for (var i = content.length - 1; i >= 0; i--) {
    final char = content[i];
    acc += (int.tryParse(char) != null ? int.parse(char) : 0) *
        pow(s1.toDouble(), content.length - i - 1).toInt();
  }

  var k = "";

  while (acc > 0) {
    final remainder = acc % 10;
    k = slice2[remainder] + k;
    acc = (acc - remainder) ~/ 10;
  }

  return k.isNotEmpty ? k : "0";
}
