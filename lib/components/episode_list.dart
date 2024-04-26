import "dart:math";

import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/kitsu.dart" as kitsu;
import "package:luffy/api/mal.dart" as mal;
import "package:luffy/util.dart";

class EpisodeList extends StatefulWidget {
  const EpisodeList({
    super.key,
    required this.episodes,
    required this.episodeProgress,
    required this.episodeInfo,
    required this.episodeInfoKitsu,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    required this.onEpisodeSelected,
  });

  final List<Episode> episodes;
  final Map<int, double> episodeProgress;
  final List<mal.Episode> episodeInfo;
  final List<kitsu.Episode> episodeInfoKitsu;
  final int watchedEpisodes;
  final int totalEpisodes;
  final void Function(Episode, int) onEpisodeSelected;

  @override
  State<EpisodeList> createState() => _EpisodeListState();
}

class _EpisodeListState extends State<EpisodeList> {
  late int _startIndex = (widget.watchedEpisodes + 1) ~/ 20 * 20;
  late int _endIndex = min(_startIndex + 20, widget.episodes.length);
  late var _showDropdown = widget.episodes.length > 20;
  late var _episodesChunks = widget.episodes.chunked(20);

  @override
  void didUpdateWidget(covariant EpisodeList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startIndex = (widget.watchedEpisodes + 1) ~/ 20 * 20;
    _endIndex = min(_startIndex + 20, widget.episodes.length);
    _showDropdown = widget.episodes.length > 20;
    _episodesChunks = widget.episodes.chunked(20);
  }

  void _onDropdownChanged(int? index) {
    if (index == null) {
      return;
    }

    setState(() {
      _startIndex = index * 20;
      _endIndex = min(_startIndex + 20, widget.episodes.length);
    });
  }

  List<DropdownMenuItem<int>> _buildDropdownItems() {
    final items = <DropdownMenuItem<int>>[];

    for (int i = 0; i < _episodesChunks.length; i++) {
      final start = i * 20 + 1;
      final end = start + _episodesChunks[i].length - 1;
      final label = "$start - $end";

      items.add(
        DropdownMenuItem(
          value: i,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
      );
    }

    return items;
  }

  Widget _buildThumbnail(Episode episode, int idx) {
    final thumbnail = widget.episodeInfoKitsu.elementAtOrNull(idx)?.image ??
        episode.thumbnailUrl;
    final horizontal = <Widget>[];
    final textHorizontal = <Widget>[];

    if (thumbnail == null) {
      horizontal
          .addAll([const Icon(Icons.play_arrow), const SizedBox(width: 8)]);
    } else {
      horizontal.addAll([
        Flexible(
          flex: 2,
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: thumbnail,
                errorWidget: (context, url, error) =>
                    const Icon(Icons.play_arrow),
                fit: BoxFit.cover,
                height: 60,
                width: 110,
              ),
              const Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                right: 0,
                child: Icon(Icons.play_arrow),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
      ]);
    }

    final altTitle = widget.episodeInfo.elementAtOrNull(idx)?.title ??
        widget.episodeInfoKitsu.elementAtOrNull(idx)?.title;

    final title = altTitle ?? episode.title;
    final rating = episode.rating;

    horizontal.add(
      Flexible(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              flex: 4,
              child: Text(
                title != null ? "${idx + 1}: $title" : "Episode ${idx + 1}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (title == altTitle && episode.title != null) ...[
              const Flexible(child: SizedBox(height: 4)),
              Flexible(
                flex: 2,
                child: Text(
                  episode.title!,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (rating != null) {
      textHorizontal.add(
        Flexible(
          child: Text(
            "$rating%",
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    final isSynced = idx < widget.watchedEpisodes;

    if (isSynced) {
      textHorizontal.addAll([
        const SizedBox(width: 4),
        const Icon(
          Icons.check,
          color: Colors.green,
          size: 16,
        ),
      ]);
    }

    final row = Row(
      children: [
        ...horizontal,
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: textHorizontal,
          ),
        ),
      ],
    );

    final itemsVertical = <Widget>[const SizedBox(height: 8)];
    final synopsis = episode.synopsis;

    if (synopsis != null && synopsis.isNotEmpty) {
      itemsVertical.add(
        Expanded(
          child: Text(
            synopsis,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    final episodeProgress = widget.episodeProgress[idx];
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (episodeProgress != null && episodeProgress.isFinite) {
      itemsVertical.add(
        LinearProgressIndicator(
          value: episodeProgress,
          backgroundColor: primaryColor.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation(primaryColor),
        ),
      );
    }

    if (itemsVertical.length > 1) {
      return Column(
        children: [
          Flexible(child: row),
          ...itemsVertical,
        ],
      );
    }

    return row;
  }

  @override
  Widget build(BuildContext context) {
    final episodesToShow = widget.episodes.sublist(_startIndex, _endIndex);

    double getEpisodeToShowHeight(Episode episode) {
      final hasSynopsis = episode.synopsis != null;

      double ret = 100;

      if (hasSynopsis) {
        ret += 48;
      }

      return ret;
    }

    final totalHeight = episodesToShow.fold(
      0.0,
      (previousValue, episode) {
        return previousValue + getEpisodeToShowHeight(episode);
      },
    );

    return SizedBox(
      height: totalHeight + 64,
      child: Column(
        children: [
          Row(
            children: [
              if (_showDropdown)
                DropdownButton(
                  value: _startIndex ~/ 20,
                  onChanged: _onDropdownChanged,
                  items: _buildDropdownItems(),
                )
              else
                const SizedBox(),
              const SizedBox(width: 8),
              Text("${widget.episodes.length} episodes"),
              const SizedBox(width: 8),
              Text(
                "${widget.totalEpisodes} episodes",
                style: const TextStyle(color: Colors.blue),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: totalHeight,
                child: Column(
                  children: episodesToShow.asMap().entries.map((e) {
                    final episode = e.value;

                    final item = SizedBox(
                      height: getEpisodeToShowHeight(episode),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onEpisodeSelected(
                              episode,
                              _startIndex + e.key,
                            );
                          },
                          splashColor: Colors.grey,
                          splashFactory: InkRipple.splashFactory,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              8,
                            ),
                            child: _buildThumbnail(
                              episode,
                              _startIndex + e.key,
                            ),
                          ),
                        ),
                      ),
                    );

                    return item;
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
