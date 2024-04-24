import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/history.dart";
import "package:luffy/api/kitsu.dart" as kitsu;
import "package:luffy/api/mal.dart" as mal;
import "package:luffy/components/episode_list.dart";
import "package:luffy/screens/video_player.dart";
import "package:luffy/util.dart";
import "package:string_similarity/string_similarity.dart";
import "package:tuple/tuple.dart";

class _Data {
  _Data({
    required this.anime,
    required this.info,
    required this.moreInfo,
    required this.episodes,
    required this.progress,
  });

  final Anime anime;
  final List<mal.Episode> info;
  final List<kitsu.Episode> moreInfo;
  final List<Episode> episodes;
  final Map<int, double> progress;
}

class WatchScreen extends StatefulWidget {
  const WatchScreen({
    super.key,
    required this.animeId,
    required this.title,
    required this.watchedEpisodes,
    required this.totalEpisodes,
  });

  final int animeId;
  final String title;
  final int? watchedEpisodes;
  final int? totalEpisodes;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<_Data?> _dataFuture;
  AnimeSource _extractor = sources.first;
  int _extractorIndex = 0;

  Future<_Data?> _getData(bool firstTime) async {
    final thumb = await kitsu.KituService.search(widget.animeId);
    final anime = await _getAnime(firstTime);

    if (anime == null) {
      return null;
    }

    final episodes = await _extractor.getEpisodes(anime);

    if (episodes.isEmpty) {
      return null;
    }

    final history =
        await HistoryService.getMedia("${_extractor.name}-${widget.animeId}");

    prints(
      "History for ${_extractor.name}-${widget.animeId}: ${history?.toJson()}",
    );

    return _Data(
      anime: anime,
      info: await mal.MalService.getAnimeEpisodes(widget.animeId),
      moreInfo: thumb,
      episodes: episodes,
      progress: history?.progress ?? {},
    );
  }

  Future<Anime?> _getAnime(
    bool firstTime,
  ) async {
    Future<Anime?> bestMatch() async {
      final results = await _extractor.search(widget.title);

      if (results.isEmpty) {
        return null;
      }

      final titles = results.map((e) => e.title).toList();
      prints("Matching ${widget.title} against: $titles");
      final best = widget.title.bestMatch(titles);
      prints("Ratings: ${best.ratings}");
      return results[best.bestMatchIndex];
    }

    if (!firstTime) {
      return bestMatch();
    }

    prints("Extractor index BEFORE: $_extractorIndex");

    for (; _extractorIndex < sources.length; _extractorIndex++) {
      _extractor = sources[_extractorIndex];

      final best = await bestMatch();

      if (best == null) {
        continue;
      }

      if (_extractorIndex >= sources.length - 1) {
        _extractorIndex = 0;
      }

      prints("Extractor index AFTER: $_extractorIndex");
      setState(() {});
      return best;
    }

    return null;
  }

  void _handleExtractorChanged(int? idx) {
    if (idx == null || idx == _extractorIndex) {
      return;
    }

    setState(() {
      _extractorIndex = idx;
      _extractor = sources[idx];
      _dataFuture = _getData(false);
    });
  }

  Tuple2<List<Widget>, double?> _buildLocalResumeButton(
    _Data data,
  ) {
    final episodeProgress = data.progress;

    if (episodeProgress.isEmpty) {
      return const Tuple2([], null);
    }

    final recentProgress = episodeProgress.entries.reduce(
      (value, element) => element.value > value.value ? element : value,
    );

    return Tuple2(
      [
        TextButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(
              Theme.of(context).colorScheme.surface,
            ),
          ),
          onPressed: () async {
            if (!context.mounted) {
              return;
            }

            final episode = data.episodes[recentProgress.key];
            final idx = recentProgress.key;

            _handleEpisodeSelected(episode, idx, data);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow),
              const SizedBox(width: 8),
              Text("Resume Episode ${recentProgress.key + 1}"),
            ],
          ),
        ),
      ],
      recentProgress.value,
    );
  }

  List<Widget> _buildMalWatchButton(_Data data) {
    final watchedEpisodes = widget.watchedEpisodes ?? 0;
    final proposedEpisode = watchedEpisodes + 1;
    final totalEpisodes = widget.totalEpisodes;

    if (totalEpisodes == null || proposedEpisode > totalEpisodes) {
      return [];
    }

    return [
      TextButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(
            Theme.of(context).colorScheme.surface,
          ),
          foregroundColor: MaterialStateProperty.all(Colors.blue),
        ),
        onPressed: () async {
          if (!context.mounted) {
            return;
          }

          final episode = data.episodes[watchedEpisodes];
          final idx = watchedEpisodes;

          _handleEpisodeSelected(episode, idx, data);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow),
            const SizedBox(width: 8),
            Text("Watch Episode ${watchedEpisodes + 1}"),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildResumeButton(_Data data) {
    final localResume = _buildLocalResumeButton(data);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final recentProgress = localResume.item2;
    final progressBar = recentProgress != null && recentProgress.isFinite
        ? [
            LinearProgressIndicator(
              value: recentProgress,
              backgroundColor: primaryColor.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(primaryColor),
            ),
          ]
        : [];

    return [
      SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...localResume.item1,
                ..._buildMalWatchButton(data),
              ],
            ),
            const SizedBox(height: 8),
            ...progressBar,
          ],
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  Future<void> _handleEpisodeSelected(
    Episode episode,
    int idx,
    _Data data,
  ) async {
    if (!context.mounted) {
      return;
    }

    final episodeProgress = data.progress[idx];

    final progress = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          showId: "${_extractor.name}-${widget.animeId}",
          showTitle: widget.title,
          episode: episode,
          episodeNum: idx,
          sourceName: _extractor.name,
          savedProgress: episodeProgress,
          imageUrl: episode.thumbnailUrl ?? data.anime.imageUrl,
          episodes: data.episodes,
          sourceFetcher: (ep) => _extractor.getSources(ep),
          animeId: widget.animeId,
          showUrl: data.anime.url,
        ),
      ),
    );

    if (progress != null && progress.isFinite) {
      setState(() {
        data.progress[idx] = progress;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _dataFuture = _getData(true);
  }

  List<Widget> _buildDropdownButton() {
    return [
      DropdownButton(
        value: _extractorIndex,
        onChanged: _handleExtractorChanged,
        items: sources
            .asMap()
            .entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value.name),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder(
          future: _dataFuture,
          builder: (context, snapshot) {
            final data = snapshot.data;

            if (snapshot.connectionState == ConnectionState.none) {
              return Column(
                children: _buildDropdownButton(),
              );
            }

            if (snapshot.connectionState != ConnectionState.done) {
              return SizedBox(
                height: MediaQuery.of(context).size.height,
                child: Column(
                  children: [
                    ..._buildDropdownButton(),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ),
              );
            }

            if (data == null) {
              return Column(
                children: [
                  ..._buildDropdownButton(),
                  const SizedBox(height: 16),
                  const Text("No results found"),
                ],
              );
            }

            return Column(
              children: [
                ..._buildDropdownButton(),
                const SizedBox(height: 8),
                Text(
                  "Match: ${data.anime.title}",
                ),
                const SizedBox(height: 8),
                CachedNetworkImage(
                  imageUrl: data.anime.imageUrl ?? "",
                  height: 200,
                  errorWidget: (context, url, error) => Container(),
                ),
                const SizedBox(height: 8),
                ..._buildResumeButton(data),
                EpisodeList(
                  episodes: data.episodes,
                  episodeInfo: data.info,
                  episodeInfoKitsu: data.moreInfo,
                  episodeProgress: data.progress,
                  watchedEpisodes: widget.watchedEpisodes ?? 0,
                  totalEpisodes: widget.totalEpisodes ?? 0,
                  onEpisodeSelected: (ep, idx) {
                    _handleEpisodeSelected(
                      ep,
                      idx,
                      data,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
