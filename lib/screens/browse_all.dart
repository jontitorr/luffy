import "package:cached_network_image/cached_network_image.dart";
import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:luffy/api/anilist.dart";
import "package:luffy/screens/details.dart";
import "package:luffy/util.dart";

class BrowseAllScreen extends StatefulWidget {
  const BrowseAllScreen({
    super.key,
    required this.animeFuture,
    required this.title,
  });

  final Future<PageResult?> Function(int page) animeFuture;
  final String title;

  @override
  State<BrowseAllScreen> createState() => _BrowseAllScreenState();
}

class _BrowseAllScreenState extends State<BrowseAllScreen> {
  bool _isLoading = false;
  int _page = 1;
  PageResult? _pageResult;
  late Future<PageResult?> _pageResultFuture;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _pageResultFuture = _fetchData();
    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.position.pixels ==
                _scrollController.position.maxScrollExtent &&
            !_isLoading &&
            (_pageResult?.pageInfo.hasNextPage ?? false)) {
          _fetchData();
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<PageResult?> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      prints("Fetching data for page $_page");
      final nextPageResult = await widget.animeFuture(_page);

      if (nextPageResult == null) {
        return null;
      }

      setState(() {
        _pageResult = PageResult(
          pageInfo: nextPageResult.pageInfo,
          results: [..._pageResult?.results ?? [], ...nextPageResult.results],
        );
        _page++;
      });
    } catch (error) {
      prints("Error fetching data: $error");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    return _pageResult;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: FutureBuilder(
        future: _pageResultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final result = snapshot.data;

          if (result == null || result.results.isEmpty) {
            return const Center(
              child: Text("No results found"),
            );
          }

          final animes = _pageResult!.results;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                backgroundColor: Theme.of(context).colorScheme.background,
                actionsIconTheme: IconThemeData(
                  color: Theme.of(context).colorScheme.onBackground,
                ),
                title: const Text(
                  "Popular",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                floating: true,
                snap: true,
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.sort),
                    onPressed: () {
                      // Add functionality for sorting
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {
                      // Add functionality for filtering
                    },
                  ),
                ],
              ),
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).orientation ==
                            Orientation.portrait
                        ? 2
                        : 6,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 9 / 16, // Consistent aspect ratio of 9:16
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == animes.length) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Opacity(
                              opacity: _isLoading ? 1.0 : 00,
                              child: const CircularProgressIndicator(),
                            ),
                          ),
                        );
                      } else {
                        return AnimePoster(
                          anime: animes[index],
                        );
                      }
                    },
                    childCount: animes.length + 1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AnimePoster extends StatelessWidget {
  const AnimePoster({
    super.key,
    required this.anime,
  });
  final SearchResult anime;

  @override
  Widget build(BuildContext context) {
    final dub = anime.languages.firstWhereOrNull((e) => e != "Japanese");
    final sub = anime.languages.firstWhereOrNull((e) => e == "Japanese");
    var languageStr =
        "${dub != null ? "Dub $dub" : ""} ${sub != null ? "${dub != null ? "| " : ""}Sub" : ""}";
    if (languageStr.isEmpty) {
      languageStr = "Unknown";
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: anime.coverImage,
                  fit: BoxFit.cover,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                child: Text(
                  anime.titleUserPreferred,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
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
            ],
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Colors.black.withOpacity(0.2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailsScreen(
                      animeId: anime.id,
                      malId: anime.malId,
                      title: anime.titleUserPreferred,
                      imageUrl: anime.coverImage,
                      bannerImageUrl: anime.bannerImage,
                      titleRomaji: anime.titleRomaji,
                      totalEpisodes: anime.episodes,
                    ),
                  ),
                );
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
              // Handle menu item selection here
              prints("You selected: $value");
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: "add",
                child: Text("Add To List"),
              ),
              const PopupMenuItem<String>(
                value: "watch",
                child: Text("Watch Now"),
              ),
              const PopupMenuItem<String>(
                value: "share",
                child: Text("Share"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
