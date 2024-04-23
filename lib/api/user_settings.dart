import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:luffy/util.dart";

const _storage = FlutterSecureStorage();

Map<String, dynamic> _defaultSettings() {
  const color = Colors.blue;

  return {
    "light_theme_color": color.value,
    "dark_theme_color": color.value,
    "welcome_screen_shown": false,
  };
}

class UserSettings {
  UserSettings._(Map<String, dynamic> json)
      : lightThemeColor = Color(json["light_theme_color"]),
        darkThemeColor = Color(json["dark_theme_color"]),
        welcomeScreenShown = json["welcome_screen_shown"];

  Map<String, dynamic> toJson() => {
        "light_theme_color": lightThemeColor.value,
        "dark_theme_color": darkThemeColor.value,
        "welcome_screen_shown": welcomeScreenShown,
      };

  static UserSettings? _instance;
  final List<Function(UserSettings)> _listeners = [];

  Color lightThemeColor;
  Color darkThemeColor;
  bool welcomeScreenShown;

  static Future<UserSettings> getInstance() async {
    try {
      if (_instance == null) {
        final settings = tryJsonDecode(await _storage.read(key: "settings"));

        _instance = UserSettings._(
          settings ?? _defaultSettings(),
        );

        prints("Settings: ${_instance?.toJson()}");

        if (settings == null) {
          await _storage.write(
            key: "settings",
            value: jsonEncode(_instance!.toJson()),
          );
        }
      }

      return _instance!;
    } catch (e) {
      return UserSettings._(
        _defaultSettings(),
      );
    }
  }

  static Future<void> registerListener(
    Function(UserSettings) listener,
  ) async {
    (await getInstance())._listeners.add(listener);
  }

  static Future<void> unregisterListener(
    Function(UserSettings) listener,
  ) async {
    (await getInstance())._listeners.remove(listener);
  }

  static Future<void> notifyListeners() async {
    final instance = await getInstance();
    prints("Notifying ${instance._listeners.length} listeners");

    for (final element in instance._listeners) {
      element(instance);
    }
  }

  Future<void> changeDarkThemeColor(Color color) async {
    (await getInstance()).darkThemeColor = color;
    await _storage.write(
      key: "settings",
      value: jsonEncode(_instance!.toJson()),
    );
    prints("Dark theme color changed to $color");
    await notifyListeners();
  }

  Future<void> changeLightThemeColor(Color color) async {
    (await getInstance()).lightThemeColor = color;
    await _storage.write(
      key: "settings",
      value: jsonEncode(_instance!.toJson()),
    );
    prints("Light theme color changed to $color");
    await notifyListeners();
  }

  static Future<void> setWelcomeScreenShown(bool shown) async {
    (await getInstance()).welcomeScreenShown = shown;
    await _storage.write(
      key: "settings",
      value: jsonEncode(_instance!.toJson()),
    );
    prints("Welcome screen shown set to $shown");
    await notifyListeners();
  }
}
