import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart" hide Scrollable;
import "package:intl/intl.dart";
import "package:luffy/api/anilist.dart";
import "package:luffy/api/mal.dart" as mal;
import "package:luffy/components/anime_card.dart";
import "package:luffy/components/blinking_button.dart";
import "package:luffy/components/clickable_text.dart";
import "package:luffy/components/details/character_card.dart";
import "package:luffy/components/details/relation_card.dart";
import "package:luffy/components/details/scrollable.dart";
import "package:luffy/components/mal_controls.dart";
import "package:luffy/components/parallax_container.dart";
import "package:luffy/screens/details.dart";
import "package:luffy/screens/youtube_embed.dart";

class InfoScreen extends StatefulWidget {
  const InfoScreen({
    super.key,
    required this.animeInfo,
    required this.title,
    this.titleRomaji,
    required this.startDate,
    this.bannerImageUrl,
    this.imageUrl,
    this.synopsis,
    required this.watchedEpisodes,
    required this.totalEpisodes,
    required this.score,
    required this.status,
    required this.onScoreChanged,
    required this.onStatusChanged,
    required this.onWatchedEpisodesChanged,
    required this.onSaveChanges,
    required this.showUpdateButton,
  });

  final AnimeStats? animeInfo;
  final String? imageUrl;
  final String? bannerImageUrl;
  final String startDate;
  final String? synopsis;
  final String title;
  final String? titleRomaji;
  final int totalEpisodes;
  final int? watchedEpisodes;
  final int? score;
  final mal.AnimeListStatus? status;
  final void Function(int) onScoreChanged;
  final void Function(mal.AnimeListStatus) onStatusChanged;
  final void Function(int) onWatchedEpisodesChanged;
  final void Function() onSaveChanges;
  final bool showUpdateButton;

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  List<Widget> _makeMalControls() {
    final score = widget.score;
    final status = widget.status;
    final watchedEpisodes = widget.watchedEpisodes;
    final malId = widget.animeInfo?.anime?.malId;

    if (score == null ||
        status == null ||
        watchedEpisodes == null ||
        malId == null) {
      return [];
    }

    return [
      const SizedBox(height: 16),
      MalControls(
        watchedEpisodes: watchedEpisodes,
        totalEpisodes: widget.totalEpisodes,
        score: score,
        status: status,
        onScoreChanged: widget.onScoreChanged,
        onStatusChanged: widget.onStatusChanged,
        onWatchedEpisodesChanged: widget.onWatchedEpisodesChanged,
      ),
    ];
  }

  List<Widget> _makeUpdateMalButton() {
    if (!widget.showUpdateButton) {
      return [];
    }

    return [
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: BlinkingWidget(
          blinkDuration: const Duration(milliseconds: 500),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withOpacity(0.1),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            onPressed: widget.onSaveChanges,
            child: const Text("Update"),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAddToListButton(AnimeInfo animeInfo) {
    if (widget.score != null ||
        widget.status != null ||
        widget.watchedEpisodes != null) {
      return [];
    }

    return [
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: BlinkingWidget(
          blinkDuration: const Duration(milliseconds: 500),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  Theme.of(context).colorScheme.surface.withOpacity(0.1),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            onPressed: () async {
              widget.onScoreChanged(0);
              widget.onStatusChanged(mal.AnimeListStatus.planToWatch);
              widget.onWatchedEpisodesChanged(0);
              widget.onSaveChanges();
            },
            child: const Text("Add to list"),
          ),
        ),
      ),
    ];
  }

  Row _makeRow(String left, String right) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(left)),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              right,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      );

  Widget _makeGenres(AnimeInfo? animeInfo) {
    final genres = animeInfo?.genres;

    if (genres == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const Text(
          "Genres",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          textAlign: TextAlign.left,
        ),
        const SizedBox(height: 8),
        GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisExtent: 40,
            mainAxisSpacing: 8,
            childAspectRatio: 3 / 2,
          ),
          itemCount: genres.length,
          shrinkWrap: true,
          itemBuilder: (context, idx) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    genres[idx],
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
          physics: const NeverScrollableScrollPhysics(),
        ),
      ],
    );
  }

  List<Widget> _makeCharacters(AnimeStats? animeInfo) {
    final characters = animeInfo?.anime?.characters;

    if (characters == null || characters.isEmpty) {
      return [];
    }

    return [
      const SizedBox(height: 16),
      Scrollable(
        items: characters,
        title: "Characters",
        builder: (_, idx) => CharacterCard(character: characters[idx]),
      ),
    ];
  }

  List<Widget> _makeRelations(AnimeStats? animeInfo) {
    final relations = animeInfo?.anime?.relations;

    if (relations == null || relations.isEmpty) {
      return [];
    }

    return [
      const SizedBox(height: 16),
      Scrollable(
        items: relations,
        title: "Relations",
        builder: (_, idx) => RelationCard(relation: relations[idx]),
      ),
    ];
  }

  List<Widget> _makeRecommendations(AnimeStats? animeInfo) {
    final recommendations = animeInfo?.anime?.recommendations;

    if (recommendations == null || recommendations.isEmpty) {
      return [];
    }

    return [
      const SizedBox(height: 16),
      Scrollable(
        items: recommendations,
        title: "Recommendations",
        builder: (_, idx) => AnimeCard(
          anime: recommendations[idx],
          width: 120,
          showTitle: true,
          opensDetails: true,
        ),
        spaceBetween: 24,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final animeInfo = widget.animeInfo;
    final studios = widget.animeInfo?.anime?.studios ?? [];

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: ParallaxContainer(
                backgroundImageUrl: widget.bannerImageUrl,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl:
                        widget.imageUrl ?? "https://via.placeholder.com/150",
                    errorWidget: (context, url, error) => Container(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (animeInfo?.anime != null &&
                (animeInfo?.isLoggedIn ?? false) == true) ...[
              ..._makeMalControls(),
              ..._makeUpdateMalButton(),
              ..._buildAddToListButton(animeInfo!.anime!),
            ],
            if (animeInfo?.score != null) ...[
              const SizedBox(height: 8),
              _makeRow("Mean Score:", "${animeInfo?.score}"),
            ],
            const SizedBox(height: 8),
            _makeRow("Total Episodes:", "${animeInfo?.totalEpisodes ?? "???"}"),
            const SizedBox(height: 8),
            _makeRow(
              "Average Duration:",
              "${animeInfo?.anime?.duration ?? "???"}",
            ),
            const SizedBox(height: 8),
            _makeRow(
              "Format:",
              animeInfo?.anime?.format ?? "???",
            ),
            const SizedBox(height: 8),
            _makeRow(
              "Source:",
              animeInfo?.anime?.source ?? "???",
            ),
            const SizedBox(height: 8),
            _makeRow("Studio:", studios.isNotEmpty ? studios[0].name : "???"),
            const SizedBox(height: 8),
            _makeRow(
              "Season:",
              animeInfo?.anime?.season ?? "???",
            ),
            const SizedBox(height: 8),
            if (animeInfo?.anime?.startDate != null)
              _makeRow(
                "Start Date:",
                DateFormat.yMd().format(animeInfo!.anime!.startDate!),
              ),
            const SizedBox(height: 8),
            if (animeInfo?.anime?.endDate != null)
              _makeRow(
                "End Date:",
                DateFormat.yMd().format(animeInfo!.anime!.endDate!),
              ),
            const SizedBox(height: 8),
            _makeRow(
              "Name Romaji:",
              widget.titleRomaji ?? "???",
            ),
            const SizedBox(height: 8),
            const Text(
              "Synopsis",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.left,
            ),
            ClickableText(
              animeInfo?.anime?.description ?? "No synopsis available.",
              style: const TextStyle(
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            if (animeInfo?.anime?.trailer != null) ...[
              const Text(
                "Trailer",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 8),
              YouTubeEmbed(url: animeInfo!.anime!.trailer!),
            ],
            _makeGenres(animeInfo?.anime),
            ..._makeCharacters(animeInfo),
            ..._makeRelations(animeInfo),
            ..._makeRecommendations(animeInfo),
          ],
        ),
      ),
    );
  }
}
