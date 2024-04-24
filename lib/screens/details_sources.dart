// This file is similar to details.dart but this one does not offer the source selection. It is assumed that this screen was entered from a source.

import "package:cached_network_image/cached_network_image.dart";
import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/history.dart";
import "package:luffy/api/mal.dart" as mal;
import "package:luffy/components/episode_list.dart";
import "package:luffy/screens/video_player.dart";
import "package:skeletons/skeletons.dart";
import "package:tuple/tuple.dart";

class DetailsScreenSources extends StatefulWidget {
  const DetailsScreenSources({
    super.key,
    required this.anime,
    required this.showId,
    required this.animeId,
    required this.title,
    required this.imageUrl,
    this.startDate,
    this.endDate,
    this.status,
    this.score,
    this.watchedEpisodes,
    this.totalEpisodes,
    this.coverImageUrl,
    this.titleEnJp,
    this.titleJaJp,
    this.type,
    this.onUpdate,
    required this.extractor,
  });

  final Anime anime;
  final String showId;
  final int? animeId;
  final String title;
  final String? imageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final mal.AnimeListStatus? status;
  final int? score;
  final int? watchedEpisodes;
  final int? totalEpisodes;
  final String? coverImageUrl;
  final String? titleEnJp;
  final String? titleJaJp;
  final mal.AnimeType? type;
  final void Function(
    int score,
    int watchedEpisodes,
    mal.AnimeListStatus status,
  )? onUpdate;
  final AnimeSource extractor;

  @override
  State<DetailsScreenSources> createState() => _DetailsScreenSourcesState();
}

class _AnimeAndEpisodes {
  _AnimeAndEpisodes({
    required this.anime,
    required this.episodes,
    required this.episodeProgress,
    required this.watchedEpisodes,
    required this.totalEpisodes,
  });

  final mal.MalAnime? anime;
  final List<Episode> episodes;
  List<double?> episodeProgress;
  final int? watchedEpisodes;
  final int? totalEpisodes;
}

class _DetailsScreenSourcesState extends State<DetailsScreenSources>
    with AutomaticKeepAliveClientMixin {
  late Future<_AnimeAndEpisodes?> _animeInfoFuture;
  late final int? _watchedEpisodes = widget.watchedEpisodes;

  Future<void> _handleEpisodeSelected(
    Episode episode,
    int idx,
    _AnimeAndEpisodes? animeInfo,
  ) async {
    if (!context.mounted || animeInfo == null) {
      return;
    }

    final episodeProgress = animeInfo.episodeProgress[idx];

    final progress = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          showId: widget.showId,
          showTitle: widget.title,
          episode: episode,
          episodeNum: idx,
          sourceName: widget.extractor.name,
          savedProgress: episodeProgress,
          imageUrl: episode.thumbnailUrl ??
              widget.imageUrl ??
              animeInfo.anime?.imageUrl,
          episodes: animeInfo.episodes,
          sourceFetcher: (ep) => widget.extractor.getSources(ep),
          showUrl: widget.anime.url,
        ),
      ),
    );

    if (progress != null && progress.isFinite) {
      setState(() {
        animeInfo.episodeProgress[idx] = progress;
      });
    }
  }

  Future<_AnimeAndEpisodes?> _getAnimeInfo() async {
    final episodes = await widget.extractor.getEpisodes(widget.anime);
    final history = await HistoryService.getMedia(widget.showId);

    // prints("History for ${widget.showId}: ${history?.toJson()}");

    final episodeProgress = episodes.asMap().entries.map((e) {
      final idx = e.key;
      final value = history?.progress[idx];

      if (value == null) {
        return null;
      }

      return value;
    }).toList();

    final anime = widget.animeId != null
        ? await mal.MalService.getAnimeInfo(widget.animeId!)
        : null;

    // prints("anime: $anime");

    return _AnimeAndEpisodes(
      anime: anime,
      episodes: episodes,
      episodeProgress: episodeProgress,
      totalEpisodes: widget.totalEpisodes ?? anime?.episodes ?? episodes.length,
      watchedEpisodes: widget.watchedEpisodes,
    );
  }

  Tuple2<List<Widget>, double?> _buildLocalResumeButton(
    _AnimeAndEpisodes animeInfo,
  ) {
    final episodeProgress = animeInfo.episodeProgress;

    final recentProgress = episodeProgress
        .asMap()
        .entries
        .lastWhereOrNull((e) => e.value != null && e.value!.isFinite);

    if (recentProgress == null) {
      return const Tuple2([], null);
    }

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

            final episode = animeInfo.episodes[recentProgress.key];
            final idx = recentProgress.key;

            _handleEpisodeSelected(episode, idx, animeInfo);
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

  List<Widget> _buildMalWatchButton(_AnimeAndEpisodes animeInfo) {
    final watchedEpisodes = _watchedEpisodes ?? 0;
    final proposedEpisode = watchedEpisodes + 1;
    final totalEpisodes = animeInfo.totalEpisodes;

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

          final episode = animeInfo.episodes[watchedEpisodes];
          final idx = watchedEpisodes;

          _handleEpisodeSelected(episode, idx, animeInfo);
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

  List<Widget> _buildResumeButton(_AnimeAndEpisodes? animeInfo) {
    if (animeInfo == null) {
      return [];
    }

    final localResume = _buildLocalResumeButton(animeInfo);
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
                ..._buildMalWatchButton(animeInfo),
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

  Widget _buildBody({
    required _AnimeAndEpisodes? animeInfo,
    required String? coverImageUrl,
    required bool isLoading,
  }) {
    if (isLoading) {
      return _skeletonView();
    }

    final startDate = widget.startDate != null
        ? DateFormat.yMd().format(widget.startDate!)
        : "???";

    final animePoster = widget.imageUrl ?? animeInfo?.anime?.imageUrl;

    return Container(
      height: MediaQuery.of(context).size.height,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            ...[
              SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: coverImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: coverImageUrl,
                              errorWidget: (context, url, error) => Container(
                                color: Theme.of(context).colorScheme.surface,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Theme.of(context).colorScheme.surface,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                    ),
                    Positioned(
                      top: 50,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: animePoster != null
                            ? CachedNetworkImage(
                                imageUrl: animePoster,
                                errorWidget: (context, url, error) => Container(
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                width: 100,
                                height: 140,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Theme.of(context).colorScheme.surface,
                                width: 100,
                                height: 140,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                startDate,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                animeInfo?.anime?.status ?? "N/A",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                animeInfo?.anime?.synopsis ?? "No synopsis available.",
                style: const TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              _buildGenres(animeInfo?.anime),
              const SizedBox(height: 16),
              ..._buildResumeButton(animeInfo),
              EpisodeList(
                episodes: animeInfo?.episodes ?? [],
                episodeInfo: const [],
                episodeInfoKitsu: const [],
                episodeProgress: const {},
                watchedEpisodes: animeInfo?.watchedEpisodes ?? 0,
                totalEpisodes:
                    animeInfo?.totalEpisodes ?? widget.totalEpisodes ?? 0,
                onEpisodeSelected: (episode, idx) {
                  _handleEpisodeSelected(episode, idx, animeInfo);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGenres(mal.MalAnime? animeInfo) {
    final textColorStyle = TextStyle(
      color: Theme.of(context).colorScheme.onBackground,
    );

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    if (animeInfo?.genres == null) {
      return const SizedBox.shrink();
    }

    if (isPortrait) {
      return Wrap(
        direction: Axis.vertical,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          const Text(
            "Genres:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...animeInfo!.genres!
              .map(
                (genre) => Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      genre,
                      style: textColorStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ],
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        const Text("Genres:", style: TextStyle(fontWeight: FontWeight.bold)),
        ...animeInfo!.genres!
            .map(
              (genre) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    genre,
                    style: textColorStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ],
    );
  }

  Widget _skeletonView() => Container(
        padding: const EdgeInsets.all(16),
        child: SkeletonItem(
          child: Column(
            children: [
              const Expanded(
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      // full-width cover image
                      Positioned.fill(
                        child: SkeletonAvatar(
                          style: SkeletonAvatarStyle(
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                      // anime picture centered on top of the cover image
                      Positioned(
                        top: 50,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SkeletonAvatar(
                            style: SkeletonAvatarStyle(
                              width: 100,
                              height: 140,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Flexible(
                child: SizedBox(
                  height: 8,
                ),
              ),
              Expanded(
                child: SkeletonLine(
                  style: SkeletonLineStyle(
                    alignment: AlignmentDirectional.center,
                    width: MediaQuery.of(context).size.width / 3,
                    height: 24,
                  ),
                ),
              ),
              const Flexible(
                child: SizedBox(
                  height: 8,
                ),
              ),
              Expanded(
                child: SkeletonLine(
                  style: SkeletonLineStyle(
                    alignment: AlignmentDirectional.center,
                    width: MediaQuery.of(context).size.width / 3,
                    height: 16,
                  ),
                ),
              ),
              const Flexible(
                child: SizedBox(
                  height: 8,
                ),
              ),
              Expanded(
                child: SkeletonLine(
                  style: SkeletonLineStyle(
                    alignment: AlignmentDirectional.center,
                    width: MediaQuery.of(context).size.width / 4,
                    height: 16,
                  ),
                ),
              ),
              const Flexible(
                child: SizedBox(
                  height: 8,
                ),
              ),
              SkeletonParagraph(
                style: SkeletonParagraphStyle(
                  spacing: 6,
                  lineStyle: SkeletonLineStyle(
                    randomLength: true,
                    height: 16,
                    minLength: MediaQuery.of(context).size.width / 2,
                    alignment: AlignmentDirectional.center,
                  ),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              const Expanded(
                child: SkeletonAvatar(
                  style: SkeletonAvatarStyle(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              const Flexible(
                child: SizedBox(
                  height: 8,
                ),
              ),
              const Expanded(
                child: SkeletonAvatar(
                  style: SkeletonAvatarStyle(
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  @override
  void initState() {
    super.initState();

    _animeInfoFuture = _getAnimeInfo();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SafeArea(
      child: FutureBuilder(
        future: _animeInfoFuture,
        builder: (context, snapshot) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
            ),
            body: _buildBody(
              animeInfo: snapshot.data,
              coverImageUrl: widget.coverImageUrl,
              isLoading: snapshot.connectionState != ConnectionState.done,
            ),
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
