import "package:cookie_jar/cookie_jar.dart";
import "package:dio/dio.dart";
import "package:luffy/http_client.dart";
import "package:luffy/util.dart";

Future<Cookie?> _getNewCookie(Uri url) async {
  final wellKnown =
      (await HttpClient.get("https://check.ddos-guard.net/check.js"))
          .data
          .toString()
          .substringAfterMissing("'", "")
          .substringBeforeMissing("'", "");
  final checkUrl = "${url.scheme}://${url.host + wellKnown}";
  return (await HttpClient.get(checkUrl))
      .headers
      .value("set-cookie")
      .let((c) => Cookie.fromSetCookieValue(c));
}

class DdosGuardInterceptor extends Interceptor {
  static Future<Response<dynamic>> get(
    String url,
  ) async {
    try {
      final res = await HttpClient.get(url, useNewClient: true);
      return res;
    } on DioException catch (e, _) {
      final res = e.response;

      if (res == null) {
        rethrow;
      }

      await _getNewCookie(Uri.parse(url));

      return HttpClient.get(url, useNewClient: true);
    }
  }
}
