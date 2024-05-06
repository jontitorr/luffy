import "package:cached_network_image/cached_network_image.dart";
import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/history.dart";
import "package:luffy/api/kitsu.dart" as kitsu;
import "package:luffy/api/mal.dart" as mal;
import "package:luffy/components/episode_list.dart";
import "package:luffy/screens/video_player.dart";
import "package:luffy/util.dart";
import "package:string_similarity/string_similarity.dart";

class _Data {
  _Data({
    required this.animes,
    required this.info,
    required this.moreInfo,
    required this.episodes,
    required this.progress,
  });

  final List<Anime> animes;
  final List<mal.Episode> info;
  final List<kitsu.Episode> moreInfo;
  final List<Episode> episodes;
  final Map<int, double> progress;
}

class WatchScreen extends StatefulWidget {
  const WatchScreen({
    super.key,
    this.animeId,
    this.showId,
    required this.title,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    required this.languages,
  });

  final int? animeId;
  final String? showId;
  final String title;
  final int? watchedEpisodes;
  final int? totalEpisodes;
  final List<String> languages;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<_Data?> _dataFuture;
  AnimeSource _extractor = sources.first;
  int _extractorIndex = 0;
  var _isDubSelected = false;
  int _animeIndex = 0;

  void _toggleDubSubMode(bool? value) {
    if (value != null) {
      setState(() {
        _isDubSelected = value;
      });
    }
  }

  List<Episode> _filterEpisodes(List<Episode> episodes) {
    return episodes
        .where((episode) => episode.isDub == _isDubSelected)
        .toList();
  }

  Future<_Data?> _getData(bool firstTime) async {
    final animeId = widget.animeId;
    final thumb =
        animeId != null ? await kitsu.KituService.search(animeId) : null;
    final animes = await _getAnimes(firstTime);

    if (firstTime) {
      _animeIndex = widget.title
          .bestMatch(animes.map((e) => e.title).toList())
          .bestMatchIndex;
    }

    final anime = animes[_animeIndex];
    final episodes = await _extractor.getEpisodes(anime);

    if (episodes.isEmpty) {
      return null;
    }

    final history = widget.showId != null
        ? await HistoryService.getMedia(widget.showId!)
        : null;

    return _Data(
      animes: animes,
      info:
          animeId != null ? await mal.MalService.getAnimeEpisodes(animeId) : [],
      moreInfo: thumb ?? [],
      episodes: episodes,
      progress: history?.progress.map((k, v) => MapEntry(k, v.progress)) ?? {},
    );
  }

  Future<List<Anime>> _getAnimes(
    bool firstTime,
  ) async {
    if (!firstTime) {
      return _extractor.search(widget.title);
    }

    final sourceName = widget.showId?.split("-").firstOrNull;

    if (sourceName != null) {
      setState(() {});
      _extractorIndex =
          sources.indexWhere((element) => element.name == sourceName);
      _extractor = sources[_extractorIndex];
      final ret = await _extractor.search(widget.title);
      setState(() {});
      return ret;
    }

    prints("Extractor index BEFORE: $_extractorIndex");

    for (; _extractorIndex < sources.length; _extractorIndex++) {
      _extractor = sources[_extractorIndex];

      final results = await _extractor.search(widget.title);

      if (results.isEmpty) {
        continue;
      }

      if (_extractorIndex >= sources.length - 1) {
        _extractorIndex = 0;
      }

      prints("Extractor index AFTER: $_extractorIndex");
      setState(() {});
      return results;
    }

    return [];
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

  (List<Widget>, double?) _buildLocalResumeButton(
    _Data data,
  ) {
    final episodeProgress = data.progress;

    if (episodeProgress.isEmpty) {
      return ([], null);
    }

    final recentProgress = episodeProgress.entries.reduce(
      (value, element) => element.value > value.value ? element : value,
    );

    return (
      [
        TextButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(
              Theme.of(context).colorScheme.surface,
            ),
          ),
          onPressed: () async {
            if (!context.mounted) {
              _handleEpisodeSelected(
                _filterEpisodes(data.episodes)[recentProgress.key],
                data,
              );
            }
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
          if (context.mounted) {
            _handleEpisodeSelected(
              _filterEpisodes(data.episodes)[watchedEpisodes],
              data,
            );
          }
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
    final recentProgress = localResume.$2;
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
                ...localResume.$1,
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
    _Data data,
  ) async {
    if (!context.mounted) {
      return;
    }

    final filtered = _filterEpisodes(data.episodes);
    final idx = filtered.indexOf(episode);
    final episodeProgress =
        data.progress.entries.firstWhereOrNull((e) => e.key == idx)?.value;
    final moreInfo = data.moreInfo.elementAtOrNull(idx);
    final episodes = filtered
        .map(
          (e) => e.copyWith(
            title: moreInfo?.title,
            thumbnailUrl: moreInfo?.image,
          ),
        )
        .toList();
    final anime = data.animes[_animeIndex];

    final progress = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          showId: "${_extractor.name}-${widget.animeId}",
          showTitle: widget.title,
          episode: episodes[idx],
          episodeNum: idx,
          sourceName: _extractor.name,
          savedProgress: episodeProgress,
          imageUrl: anime.imageUrl,
          episodes: episodes,
          sourceFetcher: (ep) => _extractor.getSources(ep),
          animeId: widget.animeId,
          showUrl: anime.url,
          languages: widget.languages,
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
                _AnimeSelect(
                  animes: data.animes,
                  onAnimeClicked: (idx) {
                    if (idx != _animeIndex) {
                      setState(() {
                        _animeIndex = idx;
                        _dataFuture = _getData(false);
                      });
                    }
                  },
                  currentIndex: _animeIndex,
                ),
                const SizedBox(height: 8),
                ..._buildResumeButton(data),
                if (data.episodes.any((e) => e.isDub))
                  Row(
                    children: [
                      Radio(
                        value: false,
                        groupValue: _isDubSelected,
                        onChanged: _toggleDubSubMode,
                      ),
                      const Text("Sub"),
                      Radio(
                        value: true,
                        groupValue: _isDubSelected,
                        onChanged: _toggleDubSubMode,
                      ),
                      const Text("Dub"),
                    ],
                  ),
                EpisodeList(
                  episodes: _filterEpisodes(data.episodes),
                  episodeInfo: data.info,
                  episodeInfoKitsu: data.moreInfo,
                  episodeProgress: data.progress,
                  watchedEpisodes: widget.watchedEpisodes ?? 0,
                  totalEpisodes: widget.totalEpisodes ?? 0,
                  onEpisodeSelected: (ep) {
                    _handleEpisodeSelected(
                      ep,
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

class _AnimeSelect extends StatelessWidget {
  const _AnimeSelect({
    required this.animes,
    required this.onAnimeClicked,
    required this.currentIndex,
  });

  final List<Anime> animes;
  final Function(int) onAnimeClicked;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showAnimeGridDialog(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Text(
              animes[currentIndex].title,
            ),
            const SizedBox(height: 8),
            CachedNetworkImage(
              imageUrl: animes[currentIndex].imageUrl ?? "",
              height: 200,
              errorWidget: (context, url, error) => Container(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnimeGridDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          elevation: 0,
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: animes.length,
              itemBuilder: (context, index) {
                final anime = animes[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    onAnimeClicked(index);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: CachedNetworkImage(
                          imageUrl: anime.imageUrl ?? "",
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Text(anime.title, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
