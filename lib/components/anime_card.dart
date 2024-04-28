import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:luffy/api/anilist.dart";
import "package:luffy/screens/details.dart";

class AnimeCard extends StatelessWidget {
  const AnimeCard({
    super.key,
    required this.anime,
    this.width,
    this.height,
    this.showTitle = false,
    this.opensDetails = false,
  });

  final SearchResult anime;
  final double? width;
  final double? height;
  final bool showTitle;
  final bool opensDetails;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: opensDetails
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailsScreen(
                    animeId: anime.id,
                    malId: anime.malId,
                    title: anime.titleEnglish ?? anime.titleUserPreferred,
                    imageUrl: anime.coverImage,
                    bannerImageUrl: anime.bannerImage,
                    titleRomaji: anime.titleRomaji,
                    totalEpisodes: anime.episodes,
                  ),
                ),
              )
          : null,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Flexible(
              flex: 10,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        CachedNetworkImage(
                          imageUrl: anime.coverImage,
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(context).colorScheme.surface,
                          ),
                          width: width,
                          height: height,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            width: 40,
                            height: 20,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    anime.meanScore?.toString() ?? "N/A",
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.star,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (anime.status == "RELEASING")
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                        width: 10,
                        height: 10,
                      ),
                    ),
                ],
              ),
            ),
            if (showTitle) ...[
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  anime.titleEnglish ?? anime.titleUserPreferred,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
