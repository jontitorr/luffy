import "package:cookie_jar/cookie_jar.dart";
import "package:dio/dio.dart";
import "package:dio_cookie_manager/dio_cookie_manager.dart";
import "package:luffy/util.dart";
import "package:path_provider/path_provider.dart";
import "package:pretty_dio_logger/pretty_dio_logger.dart";

class _Client {
  _Client._();

  final _client = Dio();
  bool _isInitialized = false;
  CookieManager? _cookieManager;

  static final _instance = _Client._();

  static Future<_Client> getInstance() async {
    final self = _instance;

    if (!self._isInitialized) {
      final appDocDir = await getApplicationDocumentsDirectory();
      final jar = PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage("${appDocDir.path}/.cookies/"),
      );
      self._cookieManager = CookieManager(jar);
      self._client.interceptors.add(self._cookieManager!);
      self._client.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
        ),
      );
      self._client.options.connectTimeout = const Duration(seconds: 30);
      self._client.options.followRedirects = false;
      self._client.options.validateStatus =
          (status) => status != null && status >= 200 && status < 400;
      _instance._isInitialized = true;
    }

    return self;
  }

  static Future<Response> get(
    String url, {
    Map<String, String>? headers,
    Options? options,
    bool followRedirects = true,
  }) async {
    headers ??= {};
    options ??= Options(
      headers: headers,
    );

    final self = await getInstance();
    var res = await self._client.get(url, options: options);
    var location = res.headers.value("location");

    while (followRedirects && location != null) {
      res = await self._client.get(location, options: options);
      location = res.headers.value("location");
    }

    return res;
  }
}

Future<Cookie?> _getNewCookie(Uri url) async {
  final wellKnown = (await _Client.get("https://check.ddos-guard.net/check.js"))
      .data
      .toString()
      .substringAfterMissing("'", "")
      .substringBeforeMissing("'", "");
  final checkUrl = "${url.scheme}://${url.host + wellKnown}";
  return (await _Client.get(checkUrl))
      .headers
      .value("set-cookie")
      .let((c) => Cookie.fromSetCookieValue(c));
}

class DdosGuardInterceptor extends Interceptor {
  static const List<int> ERROR_CODES = [403];
  static const List<String> SERVER_CHECK = ["ddos-guard"];

  static Future<Response<dynamic>> intercept(
    String url,
  ) async {
    try {
      final res = await _Client.get(url);
      return res;
    } on DioException catch (e, _) {
      final res = e.response;

      if (res == null) {
        rethrow;
      }

      await _getNewCookie(Uri.parse(url));

      return _Client.get(url);
    }
  }

  // Static Get function
  static Future<Response<dynamic>> get(String url) async {
    return intercept(
      url,
    );
  }
}
