import "package:custom_refresh_indicator/custom_refresh_indicator.dart";
import "package:flutter/material.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/history.dart";
import "package:luffy/screens/details_sources.dart";
import "package:luffy/screens/history_card.dart";
import "package:responsive_framework/responsive_framework.dart";

class _Data {
  _Data({
    required this.history,
  });

  final List<HistoryEntry> history;
}

class HomeScreenInner extends StatefulWidget {
  const HomeScreenInner({super.key});

  @override
  State<HomeScreenInner> createState() => _HomeScreenInnerState();
}

class _HomeScreenInnerState extends State<HomeScreenInner>
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
            appBar: AppBar(
              title: const Text(
                "History",
              ),
            ),
            body: CustomRefreshIndicator(
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
              child: GridView.count(
                crossAxisCount:
                    ResponsiveBreakpoints.of(context).isMobile ? 2 : 4,
                childAspectRatio:
                    ResponsiveBreakpoints.of(context).isMobile ? 1.4 : 1.2,
                padding: const EdgeInsets.all(16),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: List.generate(
                  history.length,
                  (idx) {
                    final e = history[idx];
                    final sourceName = e.id.split("-").elementAt(0);
                    final extractor = sources.firstWhere(
                      (source) => source.name == sourceName,
                    );

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailsScreenSources(
                              anime: Anime(
                                title: e.title,
                                imageUrl: e.imageUrl,
                                url: e.showUrl,
                              ),
                              animeId: e.animeId,
                              showId: e.id,
                              imageUrl: e.imageUrl,
                              title: e.title,
                              extractor: extractor,
                            ),
                          ),
                        );
                      },
                      child: HistoryCard(
                        entry: e,
                      ),
                    );
                  },
                ),
              ),
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
