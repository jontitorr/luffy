import "package:cached_network_image/cached_network_image.dart";
import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/history.dart";
import "package:luffy/api/kitsu.dart";
import "package:luffy/screens/details.dart";
import "package:luffy/screens/video_player.dart";
import "package:luffy/util.dart";
import "package:string_similarity/string_similarity.dart";

class _Data {
  _Data({
    required this.history,
  });

  final List<HistoryEntry> history;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<_Data?> _dataFuture;

  void _onHistoryUpdate(List<HistoryEntry> e) {
    setState(() {
      _dataFuture = _getData();
    });
  }

  Future<_Data?> _getData() async {
    final history = await HistoryService.getHistory();

    return _Data(
      history: history,
    );
  }

  @override
  void initState() {
    super.initState();

    _dataFuture = () async {
      await HistoryService.registerListener(_onHistoryUpdate);
      return _getData();
    }();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return FutureBuilder(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final data = snapshot.data;

        if (data == null) {
          return const Center(
            child: Text("No data"),
          );
        }

        final history = data.history;

        return SafeArea(
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Theme.of(context).colorScheme.background,
                  actionsIconTheme: IconThemeData(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                  floating: true,
                  snap: true,
                  automaticallyImplyLeading: false,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1.0),
                    child: Container(
                      height: 2.0,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.2),
                    ),
                  ),
                  actions: [
                    PopupMenuButton<String>(
                      elevation: 0,
                      offset: const Offset(0, 50),
                      shape: const RoundedRectangleBorder(),
                      icon: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          "MANAGE",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onSelected: (String value) {
                        prints("You selected: $value");

                        if (value == "clear") {
                          HistoryService.clearHistory().then((e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("History cleared"),
                              ),
                            );
                          });
                        }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: "select",
                          child: Text("Select"),
                        ),
                        const PopupMenuItem<String>(
                          value: "clear",
                          child: Text(
                            "Clear History",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 4.0,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).orientation ==
                              Orientation.portrait
                          ? 2
                          : 6,
                      // mainAxisExtent: 300,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 9 / 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _Card(
                          entry: history[index],
                          sourceName: history[index].id.split("-").elementAt(0),
                        );
                      },
                      childCount: history.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    HistoryService.unregisterListener(_onHistoryUpdate);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}

class _Card extends StatelessWidget {
  const _Card({
    required this.entry,
    required this.sourceName,
  });
  final HistoryEntry entry;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final dub = entry.languages.firstWhereOrNull((e) => e != "Japanese");
    final sub = entry.languages.firstWhereOrNull((e) => e == "Japanese");
    var languageStr =
        "${dub != null ? "Dub $dub" : ""}${sub != null ? "${dub != null ? " | " : ""}Sub" : ""}";
    if (languageStr.isEmpty) {
      languageStr = "Unknown";
    }
    final latestEpisode = entry.progress.values.lastOrNull;

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CachedNetworkImage(
                        imageUrl:
                            latestEpisode?.thumbnailUrl ?? entry.imageUrl ?? "",
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: Theme.of(context).colorScheme.surface,
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // play arrow button with black low opacity background over the image.
                    Positioned.fill(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    latestEpisode?.title ?? "Episode 0",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    languageStr,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    sourceName,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Colors.black.withOpacity(0.2),
              onTap: () async {
                final sourceName = entry.id.split("-").elementAtOrNull(0);
                final extractor =
                    sources.firstWhereOrNull((e) => e.name == sourceName);
                if (sourceName == null || extractor == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Failed to find source!"),
                      duration: Duration(seconds: 3),
                    ),
                  );

                  return;
                }

                final results = await extractor.search(entry.title);

                if (results.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No results found!"),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }

                  return;
                }

                final animeId = entry.animeId;
                final thumb =
                    animeId != null ? await KituService.search(animeId) : null;
                final titles = results.map((e) => e.title).toList();
                final best =
                    results[entry.title.bestMatch(titles).bestMatchIndex];
                final episodes = (await extractor.getEpisodes(best))
                    .mapIndexed(
                      (i, e) => e.copyWith(
                        title: thumb?.elementAtOrNull(i)?.title,
                        thumbnailUrl: thumb?.elementAtOrNull(i)?.image,
                      ),
                    )
                    .toList();
                final latestEpisode =
                    entry.progress.values.lastOrNull?.episodeNum;

                if (latestEpisode == null || episodes.length <= latestEpisode) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No results found!"),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }

                  return;
                }

                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerScreen(
                        animeId: entry.animeId,
                        showId: entry.id,
                        showTitle: entry.title,
                        episode: episodes[latestEpisode],
                        episodes: episodes,
                        episodeNum: latestEpisode,
                        sourceFetcher: (ep) => extractor.getSources(ep),
                        sourceName: sourceName,
                        imageUrl: entry.imageUrl,
                        showUrl: entry.showUrl,
                        languages: entry.languages,
                      ),
                    ),
                  );
                }
              },
              overlayColor:
                  MaterialStateProperty.all(Colors.black.withOpacity(0.2)),
              child: Container(),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (String value) {
              prints("You selected: $value");

              if (value == "details") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsScreen(
                      animeId: entry.animeId,
                      showId: entry.id,
                      title: entry.title,
                      imageUrl: entry.imageUrl,
                      totalEpisodes: entry.totalEpisodes,
                    ),
                  ),
                );
              } else if (value == "remove") {
                HistoryService.removeMedia(entry);
              }
            },
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: "details",
                child: Text("Series Info"),
              ),
              const PopupMenuItem<String>(
                value: "remove",
                child: Text(
                  "Remove From History",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
