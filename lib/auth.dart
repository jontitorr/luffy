import "dart:convert";

import "package:color_log/color_log.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:luffy/util.dart";

const _storage = FlutterSecureStorage();
const malClientId = "688adc65bbae7a2517e8d8ed7cff8c28";

class MalToken {
  MalToken._({
    this.accessToken,
    this.expirationTime,
  });

  String? accessToken;
  int? expirationTime;
  bool canRefresh = true;

  static MalToken _instance = MalToken._();

  bool isValid() {
    if (accessToken == null || expirationTime == null) {
      return false;
    }

    final token = accessToken!;
    final exp = expirationTime!;

    return token.isNotEmpty &&
        exp > 0 &&
        DateTime.now().millisecondsSinceEpoch < exp;
  }

  static Future<MalToken?> getInstance({
    Map<String, dynamic>? json,
  }) async {
    final accessToken = json?["access_token"];
    int? expirationTime;

    if (json?["expires_in"] != null) {
      expirationTime = (DateTime.now().millisecondsSinceEpoch +
          json!["expires_in"] * 1000) as int?;
    }

    if (accessToken != null && expirationTime != null) {
      _instance.accessToken = accessToken;
      _instance.expirationTime = expirationTime;
    }

    if (!_instance.isValid()) {
      await _instance.refresh();
    }

    return _instance.isValid() ? _instance : null;
  }

  Future<void> set({
    String? accessToken,
    String? refreshToken,
    int? expirationTime,
  }) async {
    if (accessToken == null || expirationTime == null) {
      return;
    }

    await _storage.write(key: "access_token", value: accessToken);
    await _storage.write(
      key: "expiration_time",
      value: expirationTime.toString(),
    );
    await _storage.write(key: "refresh_token", value: refreshToken);

    _instance = MalToken._(
      accessToken: accessToken,
      expirationTime: expirationTime,
    );
  }

  Future<void> refresh() async {
    if (!_instance.canRefresh) {
      prints(
        "cannot refresh token, skipping...",
      );
      return;
    }

    prints("refreshing token...");

    final refresh = await _storage.read(key: "refresh_token");

    if (refresh == null) {
      _instance.canRefresh = false;
      prints("refresh token not found");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://myanimelist.net/v1/oauth2/token"),
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body:
            "grant_type=refresh_token&refresh_token=$refresh&client_id=$malClientId",
      );

      prints({"refreshResponse": response.body});

      final json = jsonDecode(response.body);
      int? expirationTime;

      if (json["expires_in"] != null) {
        expirationTime = (DateTime.now().millisecondsSinceEpoch +
            json["expires_in"] * 1000) as int?;
      }

      await _instance.set(
        accessToken: json["access_token"],
        expirationTime: expirationTime,
      );
    } catch (e) {
      prints("Failed to refresh token: $e", level: LogLevel.error);
    }
  }

  static Future<void> invalidate() async {
    _instance = MalToken._();
    await _storage.delete(key: "access_token");
    await _storage.delete(key: "expiration_time");
    await _storage.delete(key: "refresh_token");
    // TODO: Should we purge leftover data or would it be inconvenient?
    // await _storage.delete(key: "user_info");
    // await _storage.delete(key: "anime_list");
    // await _storage.delete(key: "anime_list_unformatted");
    prints("token cleared");
  }
}
