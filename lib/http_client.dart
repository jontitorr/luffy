import "package:cookie_jar/cookie_jar.dart";
import "package:dio/dio.dart";
import "package:dio_cache_interceptor/dio_cache_interceptor.dart";
import "package:dio_cache_interceptor_hive_store/dio_cache_interceptor_hive_store.dart";
import "package:dio_cookie_manager/dio_cookie_manager.dart";
import "package:luffy/util.dart";
import "package:path_provider/path_provider.dart";
import "package:pretty_dio_logger/pretty_dio_logger.dart";
import "package:uuid/uuid.dart";

const _uuid = Uuid();

String keyBuilder(RequestOptions request) {
  return _uuid.v5(
    Uuid.NAMESPACE_URL,
    request.uri.toString() + request.data.toString(),
  );
}

class HttpClient {
  HttpClient._();

  final _client = Dio();
  bool _isInitialized = false;
  CookieManager? _cookieManager;

  static final _instance = HttpClient._();

  static Future<HttpClient> getInstance() async {
    final self = _instance;

    if (!self._isInitialized) {
      prints("Initializing HttpClient...");

      final appDocDir = await getApplicationDocumentsDirectory();
      final tempDir = await getTemporaryDirectory();
      final jar = PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage("${appDocDir.path}/.cookies/"),
      );
      self._cookieManager = CookieManager(jar);
      self._client.interceptors.add(self._cookieManager!);
      self._client.interceptors.add(
        DioCacheInterceptor(
          options: CacheOptions(
            store: HiveCacheStore(tempDir.path),
            policy: CachePolicy.forceCache,
            hitCacheOnErrorExcept: [],
            allowPostMethod: true,
            keyBuilder: (req) {
              return _uuid.v5(
                Uuid.NAMESPACE_URL,
                req.uri.toString() + req.data.toString(),
              );
            },
          ),
        ),
      );
      self._client.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          responseBody: false,
        ),
      );
      self._client.options.connectTimeout = const Duration(seconds: 30);
      self._client.options.receiveTimeout = const Duration(seconds: 10);
      self._client.options.followRedirects = false;
      self._client.options.validateStatus =
          (status) => status != null && status >= 200 && status < 400;
      _instance._isInitialized = true;
      prints("HttpClient initialized");
      prints("Redirect Enabled: ${self._client.options.followRedirects}");
    }

    return self;
  }

  static Future<HttpClient> create() async {
    final self = HttpClient._();

    final appDocDir = await getApplicationDocumentsDirectory();
    final tempDir = await getTemporaryDirectory();
    final jar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage("${appDocDir.path}/.cookies/"),
    );
    self._cookieManager = CookieManager(jar);
    self._client.interceptors.add(self._cookieManager!);
    self._client.options.connectTimeout = const Duration(seconds: 30);
    self._client.options.followRedirects = false;
    self._client.options.validateStatus =
        (status) => status != null && status >= 200 && status < 400;
    _instance._isInitialized = true;

    return self;
  }

  static Future<CookieManager> getCookieManager() async {
    return (await getInstance())._cookieManager!;
  }

  static Future<Response> _request(
    String url,
    String method, {
    Map<String, String>? headers,
    Object? data,
    Options? options,
    bool followRedirects = true,
    bool useNewClient = false,
  }) async {
    options ??= Options(
      method: method,
      headers: headers,
    );
    String? location = url;

    Future<Response> impl() async {
      if (!useNewClient) {
        return (await getInstance())
            ._client
            .request(location!, data: data, options: options);
      }

      return (await create())
          ._client
          .request(location!, data: data, options: options);
    }

    var res = await impl();

    if (!followRedirects) {
      return res;
    }

    var redirects = 0;

    String? calcRedirect() {
      location = res.headers.value("location");
      if (location != null) {
        redirects++;
      }
      return location;
    }

    while (calcRedirect() != null && redirects < 20) {
      res = await impl();
    }

    return res;
  }

  static Future<Response> get(
    String url, {
    Map<String, String>? headers,
    Options? options,
    bool followRedirects = true,
    bool useNewClient = false,
  }) async {
    return _request(
      url,
      "GET",
      headers: headers,
      options: options,
      followRedirects: followRedirects,
      useNewClient: useNewClient,
    );
  }

  static Future<Response> post(
    String url, {
    Map<String, String>? headers,
    Object? data,
    Options? options,
    bool followRedirects = true,
    bool useNewClient = false,
  }) async {
    return _request(
      url,
      "POST",
      headers: headers,
      data: data,
      options: options,
      followRedirects: followRedirects,
      useNewClient: useNewClient,
    );
  }
}
