import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:luffy/api/history.dart";
import "package:luffy/util.dart";
import "package:responsive_framework/responsive_framework.dart";

class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.entry});
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    prints("HistoryCard: ${entry.imageUrl}");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 3,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: entry.imageUrl ?? "",
              fit: BoxFit.fill,
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surface,
                child: const Align(
                  child: Icon(
                    Icons.play_arrow,
                  ),
                ),
              ),
            ),
          ),
        ),
        Flexible(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    entry.title,
                    style: TextStyle(
                      fontSize:
                          ResponsiveBreakpoints.of(context).isMobile ? 12 : 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Text(
                    "Episode ${entry.progress.keys.last + 1}/${entry.totalEpisodes}",
                    style: TextStyle(
                      fontSize:
                          ResponsiveBreakpoints.of(context).isMobile ? 12 : 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
