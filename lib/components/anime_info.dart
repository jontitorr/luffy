import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";
import "package:intl/intl.dart";
import "package:luffy/api/mal.dart";
import "package:luffy/util.dart";

class AnimeInfo extends StatelessWidget {
  const AnimeInfo({super.key, required this.anime, required this.onTap});

  final AnimeListEntry anime;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    final episodesWatched = anime.watchedEpisodes;
    final episodeCount = anime.totalEpisodes;
    final episodeCountStr = episodeCount == null ? "???" : "$episodeCount";
    final score = anime.score;
    final progress =
        (episodeCount ?? 0) == 0 ? 1.0 : episodesWatched / episodeCount!;

    final startDate = anime.startDate != null
        ? DateFormat.yMd().format(anime.startDate!)
        : "???";
    final endDate =
        anime.endDate != null ? DateFormat.yMd().format(anime.endDate!) : "???";

    final badgeColor = (() {
      if (score! >= 8) {
        return Colors.lightGreen;
      }

      if (score >= 6) {
        return Colors.amber;
      }

      return Colors.red;
    })();

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          height: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
                child: CachedNetworkImage(
                  imageUrl: anime.imageUrl,
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    anime.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Flexible(
                                  child: anime.id != -1
                                      ? SvgPicture.asset(
                                          "assets/images/mal.svg",
                                          colorFilter: const ColorFilter.mode(
                                            Color.fromARGB(
                                              255,
                                              46,
                                              81,
                                              162,
                                            ),
                                            BlendMode.srcIn,
                                          ),
                                          width: 24,
                                          height: 24,
                                        )
                                      : Icon(
                                          Icons.history_outlined,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.5),
                                          size: 24,
                                        ),
                                ),
                              ],
                            ),
                            Text("$startDate - $endDate"),
                            Text("$episodesWatched/$episodeCountStr"),
                            const SizedBox(),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.1),
                                value: progress,
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
              onTap: onTap,
              overlayColor:
                  MaterialStateProperty.all(Colors.black.withOpacity(0.2)),
              child: Container(),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (score != 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    "$score",
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                )
              else
                const SizedBox(),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  prints("You selected: $value");
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
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
            ],
          ),
        ),
      ],
    );
  }
}
