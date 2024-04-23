import "package:custom_refresh_indicator/custom_refresh_indicator.dart";
import "package:flutter/material.dart";
import "package:luffy/api/mal.dart";
import "package:luffy/components/anime_info.dart";
import "package:luffy/components/loading.dart";
import "package:luffy/screens/details.dart";

class _Data {
  _Data({
    required this.animeList,
    required this.userInfo,
  });

  final AnimeList animeList;
  final UserInfo? userInfo;
}

class ListScreen extends StatefulWidget {
  const ListScreen({super.key});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<_Data?> _dataFuture;

  final List<String> _tabNames = [
    "Watching",
    "Plan to Watch",
    "On Hold",
    "Completed",
    "Dropped",
  ];

  Future<_Data?> _getData() async {
    final animeList = await MalService.getAnimeList();
    final animeListWatchingIdIdxMap = <int, int>{};

    // Create a map of the anime list's watching list's IDs to their index in the list.
    for (var i = 0; i < animeList.watching.length; i++) {
      final anime = animeList.watching[i];
      animeListWatchingIdIdxMap[anime.id] = i;
    }

    return _Data(
      animeList: animeList,
      userInfo: await MalService.getUserInfo(context: context),
    );
  }

  @override
  void initState() {
    super.initState();

    _dataFuture = _getData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingIndicator();
        }

        final data = snapshot.data;

        if (data == null) {
          return const Center(
            child: Text("No data"),
          );
        }

        final animeList = data.animeList;
        final userInfo = data.userInfo;

        return SafeArea(
          child: DefaultTabController(
            length: _tabNames.length,
            child: Scaffold(
              appBar: AppBar(
                iconTheme: Theme.of(context).iconTheme,
                title: Text(
                  "My Lists",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                bottom: TabBar(
                  tabAlignment: TabAlignment.center,
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
                  animeList.dropped,
                ]
                    .map(
                      (e) => CustomRefreshIndicator(
                        builder: MaterialIndicatorDelegate(
                          displacement: 20,
                          builder: (context, controller) {
                            final offset = controller.value * 0.5 * 3.1415;

                            return Transform.rotate(
                              angle: offset,
                              child: Icon(
                                Icons.refresh,
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
                              duration: Duration(milliseconds: 250),
                            ),
                          );

                          setState(() {
                            _dataFuture = () async {
                              final ret = await _getData();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Refreshed!"),
                                    duration: Duration(milliseconds: 250),
                                  ),
                                );
                              }

                              return ret;
                            }();
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
                                  MaterialPageRoute(
                                    builder: (context) => DetailsScreen(
                                      animeId: anime.id,
                                      malId: anime.id,
                                      isMalId: true,
                                      title: anime.title,
                                      imageUrl: anime.imageUrl,
                                      startDate: anime.startDate,
                                      endDate: anime.endDate,
                                      score: anime.score,
                                      watchedEpisodes: anime.watchedEpisodes,
                                      totalEpisodes: anime.totalEpisodes ?? 0,
                                      bannerImageUrl: anime.coverImageUrl,
                                      titleRomaji: anime.titleEnJp,
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
                                              case AnimeListStatus.watching:
                                                return animeList.watching;
                                              case AnimeListStatus.planToWatch:
                                                return animeList.planToWatch;
                                              case AnimeListStatus.onHold:
                                                return animeList.onHold;
                                              case AnimeListStatus.completed:
                                                return animeList.completed;
                                              case AnimeListStatus.dropped:
                                                return animeList.dropped;
                                            }
                                          })();

                                          final toAdd = (() {
                                            switch (status) {
                                              case AnimeListStatus.watching:
                                                return animeList.watching;
                                              case AnimeListStatus.planToWatch:
                                                return animeList.planToWatch;
                                              case AnimeListStatus.onHold:
                                                return animeList.onHold;
                                              case AnimeListStatus.completed:
                                                return animeList.completed;
                                              case AnimeListStatus.dropped:
                                                return animeList.dropped;
                                            }
                                          })();

                                          toModify.remove(anime);
                                          toAdd.insert(0, anime);
                                          anime.status = status;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                child: AnimeInfo(anime: anime),
                              ),
                            );
                          },
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
