import "package:custom_refresh_indicator/custom_refresh_indicator.dart";
import "package:flutter/material.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/history.dart";
import "package:luffy/api/mal.dart";
import "package:luffy/components/anime_info.dart";
import "package:luffy/screens/details.dart";
import "package:luffy/screens/details_sources.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<AnimeList?> _animeListFuture;

  final List<String> _tabNames = [
    "Watching",
    "Plan to Watch",
    "On Hold",
    "Completed",
    "Dropped",
  ];

  final Map<String, AnimeExtractor> _extractorsMap = sources.fold(
    {},
    (Map<String, AnimeExtractor> map, AnimeExtractor extractor) {
      map[extractor.name] = extractor;
      return map;
    },
  );

  Future<AnimeList> _getAnimeList() async {
    // return Future.value(AnimeList(
    //   completed: [],
    //   watching: List.generate(
    //       100,
    //       (index) => AnimeListEntry(
    //           id: 1,
    //           title: "title $index",
    //           imageUrl: "https://via.placeholder.com/150",
    //           status: AnimeListStatus.completed,
    //           score: 1,
    //           watchedEpisodes: 1,
    //           totalEpisodes: 2,
    //           isRewatching: false,
    //           startDate: null,
    //           endDate: null)),
    //   dropped: [],
    //   onHold: [],
    //   planToWatch: [],
    // ));

    final animeList = await MalService.getAnimeList();
    final history = await HistoryService.getHistory();
    final animeListWatchingIdIdxMap = <int, int>{};

    // Create a map of the anime list's watching list's IDs to their index in the list.
    for (var i = 0; i < animeList.watching.length; i++) {
      final anime = animeList.watching[i];
      animeListWatchingIdIdxMap[anime.id] = i;
    }

    // Add the history to the anime list's watching list. If an entry's ID is already in the list, move it to the top.
    for (final historyEntry in history) {
      final id = historyEntry.id;
      final isAnime = id != null &&
          int.tryParse(id) != null &&
          animeListWatchingIdIdxMap.containsKey(int.parse(id));

      if (isAnime) {
        final anime =
            animeList.watching[animeListWatchingIdIdxMap[int.parse(id)]!];
        final index = animeList.watching.indexOf(anime);

        animeList.watching.removeAt(index);
        animeList.watching.insert(0, anime);
      } else {
        final latestEpisode = historyEntry.progress.isNotEmpty
            ? historyEntry.progress.keys.last
            : 0;

        animeList.watching.insert(
          0,
          AnimeListEntry(
            id: -1,
            title: historyEntry.title,
            imageUrl: historyEntry.imageUrl,
            status: AnimeListStatus.watching,
            score: 0,
            watchedEpisodes: latestEpisode,
            totalEpisodes: historyEntry.totalEpisodes <= 0
                ? null
                : historyEntry.totalEpisodes,
            isRewatching: false,
            startDate: null,
            endDate: null,
            // NOTE: CoverImageUrl will be used for the determining of the source.
            coverImageUrl: historyEntry.id,
            kitsuId: null,
            titleEnJp: "",
            titleJaJp: "",
            type: AnimeType.tv,
          ),
        );
      }
    }

    return animeList;
  }

  @override
  void initState() {
    super.initState();
    _animeListFuture = _getAnimeList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder(
      future: _animeListFuture,
      builder: (context, snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
          case ConnectionState.active:
            {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
          case ConnectionState.done:
            break;
        }

        if (snapshot.data == null) {
          return const Center(
            child: Text("No data"),
          );
        }

        final animeList = snapshot.data!;

        return SafeArea(
          child: DefaultTabController(
            length: _tabNames.length,
            child: Scaffold(
              appBar: AppBar(
                title: const Text("Home"),
                bottom: TabBar(
                  isScrollable: true,
                  tabs: _tabNames.map((name) {
                    final toDisplay = (() {
                      switch (name) {
                        case "Watching":
                          return animeList.watching;
                        case "Plan to Watch":
                          return animeList.planToWatch;
                        case "On Hold":
                          return animeList.onHold;
                        case "Dropped":
                          return animeList.dropped;
                        case "Completed":
                          return animeList.completed;
                        default:
                          throw Exception("Invalid tab name");
                      }
                    })();

                    return Tab(text: "$name (${toDisplay.length})");
                  }).toList(),
                ),
              ),
              body: TabBarView(
                children: [
                  animeList.watching,
                  animeList.planToWatch,
                  animeList.onHold,
                  animeList.completed,
                  animeList.dropped
                ]
                    .map(
                      (e) => Container(
                        color: Theme.of(context).colorScheme.background,
                        child: CustomRefreshIndicator(
                          builder: MaterialIndicatorDelegate(
                            builder: (context, controller) {
                              final offset = controller.value * 0.5 * 3.1415;

                              return Transform.rotate(
                                angle: offset,
                                child: Icon(
                                  Icons.ac_unit,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 30,
                                ),
                              );
                            },
                          ),
                          onRefresh: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Refreshing..."),
                                duration: Duration(seconds: 1),
                              ),
                            );

                            // Wait for 2 seconds to simulate refreshing.
                            return Future.delayed(const Duration(seconds: 2),
                                () {
                              setState(() {
                                _animeListFuture = _getAnimeList();
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Refreshed!"),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            });
                          },
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: e.length,
                            itemBuilder: (context, index) {
                              final anime = e[index];

                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    anime.id != -1
                                        ? MaterialPageRoute(
                                            builder: (context) => DetailsScreen(
                                              animeId: anime.id.toString(),
                                              title: anime.title,
                                              imageUrl: anime.imageUrl,
                                              startDate: anime.startDate,
                                              endDate: anime.endDate,
                                              status: anime.status,
                                              score: anime.score,
                                              watchedEpisodes:
                                                  anime.watchedEpisodes,
                                              totalEpisodes:
                                                  anime.totalEpisodes ?? 0,
                                              coverImageUrl:
                                                  anime.coverImageUrl,
                                              titleEnJp: anime.titleEnJp,
                                              titleJaJp: anime.titleJaJp,
                                              type: anime.type,
                                              onUpdate: (
                                                score,
                                                watchedEpisodes,
                                                status,
                                              ) {
                                                setState(() {
                                                  anime.score = score;
                                                  anime.watchedEpisodes =
                                                      watchedEpisodes;

                                                  if (anime.status == status) {
                                                    return;
                                                  }

                                                  final toModify = (() {
                                                    switch (anime.status) {
                                                      case AnimeListStatus
                                                            .watching:
                                                        return animeList
                                                            .watching;
                                                      case AnimeListStatus
                                                            .planToWatch:
                                                        return animeList
                                                            .planToWatch;
                                                      case AnimeListStatus
                                                            .onHold:
                                                        return animeList.onHold;
                                                      case AnimeListStatus
                                                            .completed:
                                                        return animeList
                                                            .completed;
                                                      case AnimeListStatus
                                                            .dropped:
                                                        return animeList
                                                            .dropped;
                                                    }
                                                  })();

                                                  final toAdd = (() {
                                                    switch (status) {
                                                      case AnimeListStatus
                                                            .watching:
                                                        return animeList
                                                            .watching;
                                                      case AnimeListStatus
                                                            .planToWatch:
                                                        return animeList
                                                            .planToWatch;
                                                      case AnimeListStatus
                                                            .onHold:
                                                        return animeList.onHold;
                                                      case AnimeListStatus
                                                            .completed:
                                                        return animeList
                                                            .completed;
                                                      case AnimeListStatus
                                                            .dropped:
                                                        return animeList
                                                            .dropped;
                                                    }
                                                  })();

                                                  toModify.remove(anime);
                                                  toAdd.insert(0, anime);
                                                  anime.status = status;
                                                });
                                              },
                                            ),
                                          )
                                        : MaterialPageRoute(
                                            builder: (context) =>
                                                DetailsScreenSources(
                                              animeId: anime.coverImageUrl!,
                                              title: anime.title,
                                              imageUrl: anime.imageUrl,
                                              extractor: _extractorsMap[anime
                                                  .coverImageUrl!
                                                  .substring(
                                                0,
                                                anime.coverImageUrl!
                                                    .indexOf("-"),
                                              )]!,
                                              watchedEpisodes:
                                                  anime.watchedEpisodes,
                                              totalEpisodes:
                                                  anime.totalEpisodes ?? 0,
                                            ),
                                          ),
                                  ),
                                  child: AnimeInfo(anime: anime),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
