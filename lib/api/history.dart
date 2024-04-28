import "dart:convert";

import "package:collection/collection.dart";
import "package:color_log/color_log.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/util.dart";

class EpisodeEntry {
  EpisodeEntry({
    required this.episodeNum,
    required this.progress,
    required this.title,
    this.thumbnailUrl,
  });

  EpisodeEntry.fromJson(Map<String, dynamic> json)
      : episodeNum = json["episode_num"],
        progress = json["progress"],
        title = json["title"],
        thumbnailUrl = json["thumbnail_url"];

  EpisodeEntry copyWith({
    int? episodeNum,
    double? progress,
    String? title,
  }) {
    return EpisodeEntry(
      episodeNum: episodeNum ?? this.episodeNum,
      progress: progress ?? this.progress,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        "episode_num": episodeNum,
        "progress": progress,
        "title": title,
        "thumbnail_url": thumbnailUrl,
      };

  final int episodeNum;
  final double progress;
  final String title;
  final String? thumbnailUrl;
}

class HistoryEntry {
  HistoryEntry({
    required this.id,
    this.animeId,
    required this.title,
    required this.imageUrl,
    required this.progress,
    required this.totalEpisodes,
    required this.sources,
    required this.subtitles,
    required this.sourceExpiration,
    required this.showUrl,
    required this.languages,
  });

  HistoryEntry.fromJson(Map<String, dynamic> json)
      : id = json["id"],
        animeId = json["anime_id"],
        title = json["title"],
        imageUrl = json["image_url"],
        progress = json["progress"]
            .map((k, v) => MapEntry(int.parse(k), EpisodeEntry.fromJson(v))),
        totalEpisodes = json["total_episodes"],
        sources = json["sources"].map(
          (k, v) =>
              MapEntry(int.parse(k), v.map((e) => VideoSource.fromJson(e))),
        ),
        subtitles = json["subtitles"].map(
          (k, v) => MapEntry(int.parse(k), v.map((e) => Subtitle.fromJson(e))),
        ),
        sourceExpiration = DateTime.parse(json["sources_last_updated"]),
        showUrl = json["show_url"],
        languages = json["languages"];

  // The ID of the anime (if a normie show/movie will be formatted like so: "$sourceName-$showId")
  final String id;
  // The ID of the anime if its actually an anime found on MAL/Anilist
  final int? animeId;
  //  The title of the anime/show/movie
  final String title;
  // The image URL of the anime/show/movie
  final String? imageUrl;
  // The stored progress of the media (is indexed by the episode number)
  final Map<int, EpisodeEntry> progress;
  // The total number of episodes of the media
  final int totalEpisodes;
  // Sources for the media, all serialized to JSON.
  final Map<int, List<VideoSource>> sources;
  // Subtitles for the media, all serialized to JSON.
  final Map<int, List<Subtitle>> subtitles;
  // Timestamp of when sources were last updated. (Used for caching)
  final DateTime sourceExpiration;
  // The URL of the original show it belongs to (useful for looking up episodes again if needed)
  final String showUrl;
  // The languages the show is available in
  final List<String> languages;

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "anime_id": animeId,
      "title": title,
      "image_url": imageUrl,
      "progress": progress.map((k, v) => MapEntry(k.toString(), v.toJson())),
      "total_episodes": totalEpisodes,
      "sources": sources.map(
        (k, v) => MapEntry(k.toString(), v.map((e) => e.toJson()).toList()),
      ),
      "subtitles": subtitles.map(
        (k, v) => MapEntry(k.toString(), v.map((e) => e.toJson()).toList()),
      ),
      "source_expiration": sourceExpiration.toIso8601String(),
      "show_url": showUrl,
    };
  }
}

const _storage = FlutterSecureStorage();

class HistoryService {
  HistoryService._internal(List<HistoryEntry> history) {
    _history = history;
  }

  static HistoryService? _instance;

  static Future<HistoryService> _getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    try {
      final historyStr = await _storage.read(key: "history");

      prints("History: $historyStr");

      final history = historyStr != null
          ? (jsonDecode(historyStr) as List)
              .map(
                (e) => HistoryEntry(
                  id: e["id"],
                  animeId: e["anime_id"],
                  title: e["title"],
                  imageUrl: e["image_url"],
                  progress:
                      e["progress"] ?? [].map((e) => EpisodeEntry.fromJson(e)),
                  totalEpisodes: e["total_episodes"],
                  sources: e["sources"] != null
                      ? Map.fromEntries(
                          (e["sources"] as Map<String, dynamic>).entries.map(
                                (e) => MapEntry(
                                  int.parse(e.key),
                                  (e.value as List)
                                      .map((e) => VideoSource.fromJson(e))
                                      .toList(),
                                ),
                              ),
                        )
                      : {},
                  subtitles: e["subtitles"] != null
                      ? Map.fromEntries(
                          (e["subtitles"] as Map<String, dynamic>).entries.map(
                                (e) => MapEntry(
                                  int.parse(e.key),
                                  (e.value as List)
                                      .map((e) => Subtitle.fromJson(e))
                                      .toList(),
                                ),
                              ),
                        )
                      : {},
                  sourceExpiration: DateTime.parse(e["source_expiration"]),
                  showUrl: e["show_url"],
                  languages: e["languages"] ?? [],
                ),
              )
              .toList()
          : <HistoryEntry>[];

      _instance = HistoryService._internal(history);
    } catch (e) {
      prints("Failed to load history: $e", level: LogLevel.error);
      _instance = HistoryService._internal(<HistoryEntry>[]);
    }

    return _instance!;
  }

  List<HistoryEntry> _history = [];
  final List<Function(List<HistoryEntry>)> _historyListeners = [];

  List<HistoryEntry> get history => _history;

  static Future<void> addProgress(
    HistoryEntry media,
    EpisodeEntry episode,
  ) async {
    final instance = await _getInstance();
    final history = instance._history;

    // If the entry is not in the history, add it.
    final idx = (() {
      final ret = history.indexWhere((element) => element.id == media.id);

      if (ret == -1) {
        history.add(media);
        return history.length - 1;
      }

      return ret;
    })();

    // Update the media.
    // Get the element from the history.
    final element = history[idx];
    final episodeNum = episode.episodeNum;
    // Update the progress.
    element.progress[episodeNum] = episode;
    // Update the sources.
    element.sources[episodeNum] = media.sources[episodeNum]!;
    // Update the subtitles.
    element.subtitles[episodeNum] = media.subtitles[episodeNum]!;

    // Move the element to the front of the list.
    history.removeAt(idx);
    history.add(element);

    await _storage.write(
      key: "history",
      value: jsonEncode(history),
    );

    // Print the current history.
    prints("History: $history");

    await notifyListeners();
  }

  static Future<void> removeMedia(HistoryEntry media) async {
    final instance = await _getInstance();
    final history = instance._history;

    history.remove(media);
    _storage.write(key: "history", value: jsonEncode(history));
    await notifyListeners();
  }

  static Future<List<HistoryEntry>> getHistory() async {
    final instance = await _getInstance();

    prints("History: ${instance._history}");

    return instance._history.reversed.toList();
  }

  static Future<void> clearHistory() async {
    final instance = await _getInstance();

    instance._history.clear();
    await _storage.delete(key: "history");
    await notifyListeners();
  }

  static Future<HistoryEntry?> getMedia(String id) async {
    final instance = await _getInstance();

    return instance._history.firstWhereOrNull((element) => element.id == id);
  }

  static Future<void> registerListener(
    Function(List<HistoryEntry>) listener,
  ) async {
    final instance = await _getInstance();

    instance._historyListeners.add(listener);
  }

  static Future<void> unregisterListener(
    Function(List<HistoryEntry>) listener,
  ) async {
    final instance = await _getInstance();

    instance._historyListeners.remove(listener);
  }

  static Future<void> notifyListeners() async {
    final instance = await _getInstance();

    for (final element in instance._historyListeners) {
      element(instance._history);
    }
  }
}
