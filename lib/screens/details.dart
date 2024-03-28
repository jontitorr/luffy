import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:luffy/api/anilist.dart";
import "package:luffy/api/mal.dart" as mal;
import "package:luffy/components/details/skeleton.dart";
import "package:luffy/dialogs.dart";
import "package:luffy/screens/details/info.dart";
import "package:luffy/screens/details/watch.dart";
import "package:url_launcher/url_launcher.dart";

class DetailsScreen extends StatefulWidget {
  const DetailsScreen({
    super.key,
    required this.animeId,
    this.malId,
    required this.title,
    this.imageUrl,
    this.startDate,
    this.endDate,
    this.status,
    this.score,
    this.watchedEpisodes,
    this.totalEpisodes,
    this.bannerImageUrl,
    this.titleRomaji,
    this.onUpdate,
    this.isMalId = false,
  });

  final int animeId;
  final int? malId;
  final String title;
  final String? imageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final mal.AnimeListStatus? status;
  final int? score;
  final int? watchedEpisodes;
  final int? totalEpisodes;
  final String? bannerImageUrl;
  final String? titleRomaji;
  final void Function(
    int score,
    int watchedEpisodes,
    mal.AnimeListStatus status,
  )? onUpdate;
  final bool isMalId;

  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class AnimeStats {
  AnimeStats({
    required this.isLoggedIn,
    required this.anime,
    required this.totalEpisodes,
    required this.score,
    required this.watchedEpisodes,
    required this.status,
  });

  final bool isLoggedIn;
  final AnimeInfo? anime;
  final int? totalEpisodes;
  final int? score;
  final int? watchedEpisodes;
  final mal.AnimeListStatus? status;
}

class _DetailsScreenState extends State<DetailsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late Future<AnimeStats?> _animeInfoFuture;
  late int? _oldScore = widget.score;
  late int? _oldWatchedEpisodes = widget.watchedEpisodes;
  late mal.AnimeListStatus? _oldStatus = widget.status;

  late int? _score = widget.score;
  late int? _watchedEpisodes = widget.watchedEpisodes;
  late mal.AnimeListStatus? _status = widget.status;

  int _currentTab = 0;
  late TabController _tabController;

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentTab = _tabController.index;
      });
    }
  }

  Future<AnimeStats?> _getAnimeInfo({
    bool firstTime = false,
  }) async {
    final listStatus = await (() async {
      final malId = widget.malId;

      if ((malId == null) ||
          (widget.score != null &&
              widget.status != null &&
              widget.totalEpisodes != null &&
              widget.watchedEpisodes != null)) {
        return null;
      }

      return mal.MalService.getListStatusFor(malId);
    })();

    final info = await AnilistService.getAnimeInfo(
      widget.animeId,
      isMalId: widget.isMalId,
    );

    return AnimeStats(
      isLoggedIn: await mal.MalService.isLoggedIn(),
      anime: info,
      totalEpisodes: listStatus?.totalEpisodes ?? widget.totalEpisodes,
      score: listStatus?.score ?? widget.score,
      status: listStatus?.status ?? widget.status,
      watchedEpisodes: listStatus?.watchedEpisodes ?? widget.watchedEpisodes,
    );
  }

  Widget _buildBody({
    required AnimeStats? animeInfo,
    required bool isLoading,
  }) {
    if (isLoading) {
      return const Skeleton();
    }

    final info = InfoScreen(
      animeInfo: animeInfo,
      imageUrl: widget.imageUrl,
      bannerImageUrl: widget.bannerImageUrl,
      title: widget.title,
      titleRomaji: widget.titleRomaji,
      startDate: widget.startDate != null
          ? DateFormat.yMd().format(widget.startDate!)
          : "???",
      watchedEpisodes: _watchedEpisodes,
      totalEpisodes: animeInfo?.totalEpisodes ?? 0,
      score: _score,
      status: _status,
      onScoreChanged: (score) {
        setState(() {
          _score = score;
        });
      },
      onStatusChanged: (status) {
        setState(() {
          _status = status;
        });
      },
      onWatchedEpisodesChanged: (value) {
        setState(() {
          _watchedEpisodes = value;

          if (value == 0) {
            _status = mal.AnimeListStatus.planToWatch;
            return;
          }

          if (value == widget.totalEpisodes) {
            _status = mal.AnimeListStatus.completed;
            return;
          }

          if (value > 0) {
            _status = mal.AnimeListStatus.watching;
          }
        });
      },
      onSaveChanges: _saveChanges,
      showUpdateButton: _score != _oldScore ||
          _status != _oldStatus ||
          _watchedEpisodes != _oldWatchedEpisodes,
    );

    final watch = WatchScreen(
      animeId: widget.animeId,
      title: widget.title,
      watchedEpisodes: animeInfo?.watchedEpisodes ?? 0,
      totalEpisodes: animeInfo?.totalEpisodes ?? 0,
    );

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        actions: _goToMyAnimeList(),
        iconTheme: Theme.of(context).iconTheme,
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          info,
          watch,
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        currentIndex: _currentTab,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
        onTap: (idx) {
          setState(() {
            _currentTab = idx;
          });

          _tabController.animateTo(idx);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: "Info",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.movie),
            label: "Watch",
          ),
        ],
      ),
    );
  }

  List<Widget> _goToMyAnimeList() {
    final malId = widget.malId;

    if (malId == null) {
      return [];
    }

    return [
      IconButton(
        icon: const Icon(Icons.open_in_new),
        onPressed: () async {
          final uri = Uri.parse("https://myanimelist.net/anime/$malId");

          if (!await canLaunchUrl(uri)) {
            return;
          }

          await launchUrl(uri, mode: LaunchMode.externalApplication);
        },
      ),
    ];
  }

  Future<void> _saveChanges() async {
    final status = _status;
    final score = _score;
    final watchedEpisodes = _watchedEpisodes;
    final malId = widget.malId;

    if (status == null ||
        score == null ||
        watchedEpisodes == null ||
        malId == null) {
      return;
    }

    final res = await mal.MalService.updateAnimeListItem(
      malId,
      status,
      score: score,
      numWatchedEpisodes: watchedEpisodes,
    );

    if (res == null || res.statusCode != 200) {
      if (context.mounted) {
        showErrorDialog(
          context,
          "Could not update this anime. I'm guessing that MyAnimeList is down or you are not connected to the internet. Please try to update again later.",
        );
      }

      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Anime updated successfully!"),
        ),
      );
    }

    setState(() {
      _oldScore = score;
      _oldStatus = status;
      _oldWatchedEpisodes = watchedEpisodes;
    });

    widget.onUpdate?.call(score, watchedEpisodes, status);
  }

  Future<void> _onPop(bool didPop) async {
    if (didPop) {
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Save changes?",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "You have unsaved changes. Do you want to sync them with MyAnimeList?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (result != null && result) {
      await _saveChanges();
    }
  }

  void _setInitialValues(AnimeStats? animeInfo) {
    if (animeInfo == null || !mounted) {
      return;
    }

    setState(() {
      _oldScore = animeInfo.score ?? widget.score;
      _oldStatus = animeInfo.status ?? widget.status;
      _oldWatchedEpisodes = animeInfo.watchedEpisodes ?? widget.watchedEpisodes;

      _score = _oldScore;
      _status = _oldStatus;
      _watchedEpisodes = _oldWatchedEpisodes;
    });
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2, // number of tabs
      vsync: this,
    );

    _tabController.addListener(_handleTabChange);
    _animeInfoFuture = _getAnimeInfo(firstTime: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animeInfoFuture.then((animeInfo) {
        _setInitialValues(animeInfo);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return PopScope(
      canPop: _oldScore == _score &&
          _oldStatus == _status &&
          _oldWatchedEpisodes == _watchedEpisodes,
      onPopInvoked: _onPop,
      child: SafeArea(
        child: FutureBuilder(
          future: _animeInfoFuture,
          builder: (context, snapshot) {
            return _buildBody(
              animeInfo: snapshot.data,
              isLoading: snapshot.connectionState != ConnectionState.done,
            );
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
