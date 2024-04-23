import "package:cached_network_image/cached_network_image.dart";
import "package:carousel_slider/carousel_slider.dart";
import "package:collection/collection.dart";
import "package:flutter/material.dart";
import "package:luffy/api/anilist.dart";
import "package:luffy/components/anime_card.dart";
import "package:luffy/components/parallax_container.dart";
import "package:luffy/screens/details.dart";
import "package:luffy/screens/details/calen.dart";

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen>
    with AutomaticKeepAliveClientMixin {
  late Future<BrowseResult?> _animesFuture;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  String? _backgroundImage =
      "https://s4.anilist.co/file/anilistcdn/media/anime/banner/147103-MwFq1R7jphZT.jpg";

  @override
  void initState() {
    super.initState();

    _animesFuture = AnilistService.browse();

    _scrollController.addListener(() {
      final double showoffset = MediaQuery.of(context).size.height;
      setState(() {
        _showScrollToTop = _scrollController.offset > showoffset;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Browse"),
        ),
        floatingActionButton: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _showScrollToTop ? 1.0 : 0.0,
          curve: Curves.easeIn,
          child: FloatingActionButton(
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeIn,
              );
            },
            child: const Icon(Icons.arrow_upward),
          ),
        ),
        body: FutureBuilder(
          future: _animesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final topAnimes = snapshot.data;

            if (topAnimes == null) {
              return const Center(
                child: Text("No data"),
              );
            }

            return SingleChildScrollView(
              controller: _scrollController,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: ParallaxContainer(
                  backgroundImageUrl: _backgroundImage,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 200,
                        width: MediaQuery.of(context).size.width,
                        child: CarouselSlider(
                          options: CarouselOptions(
                            height: 200.0,
                            autoPlay: true,
                            viewportFraction: 1,
                            onPageChanged: (idx, _) {
                              setState(() {
                                _backgroundImage =
                                    topAnimes.trending[idx].bannerImage;
                              });
                            },
                          ),
                          items: topAnimes.trending.map((anime) {
                            return Builder(
                              builder: (context) {
                                return GestureDetector(
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Column(
                                        children: [
                                          Flexible(
                                            child: AnimeCard(
                                              anime: anime,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 8,
                                          ),
                                          if (anime.episodes != null)
                                            Text(
                                              "${anime.episodes} episodes",
                                            ),
                                        ],
                                      ),
                                      const SizedBox(
                                        width: 8,
                                      ),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              anime.titleUserPreferred,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const SizedBox(
                                              height: 8,
                                            ),
                                            Text(
                                              anime.status,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 8,
                                            ),
                                            Text(
                                              anime.genres.join(" · "),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Button which says Calendar and opens the CalendarScreen.
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CalendarScreen(),
                            ),
                          );
                        },
                        child: const Text("Calendar"),
                      ),
                      const SizedBox(height: 16),
                      // Heading for "Recently Updated"
                      const Text(
                        "Recently Updated",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      // List of recently updated
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: topAnimes.season.length,
                          padding: const EdgeInsets.all(8),
                          itemBuilder: (context, idx) {
                            final anime = topAnimes.season[idx];

                            return SizedBox(
                              width: 120,
                              child: GestureDetector(
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AnimeCard(
                                      anime: anime,
                                      width: 120,
                                      height: 150,
                                    ),
                                    const SizedBox(height: 8),
                                    Flexible(
                                      child: Text(
                                        anime.titleUserPreferred,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (context, idx) {
                            return const SizedBox(width: 8);
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Heading for "Recently Updated"
                      const Text(
                        "Popular Anime",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 16),
                      // Show the rest of the popular anime within the column to listview required.
                      ...topAnimes.popular.map((anime) {
                        final episodesStr = anime.episodes != null
                            ? "${anime.episodes} episodes"
                            : anime.nextAiringEpisode != null
                                ? "${anime.nextAiringEpisode! - 1} / ??? episodes"
                                : "???";

                        return [
                          GestureDetector(
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
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: CachedNetworkImageProvider(
                                    anime.bannerImage ?? anime.coverImage,
                                  ),
                                  fit: BoxFit.cover,
                                  opacity: 0.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: AnimeCard(
                                      anime: anime,
                                      width: 120,
                                      height: 150,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          anime.titleUserPreferred,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          anime.status,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          anime.type,
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          episodesStr,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ];
                      }).flattened,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
