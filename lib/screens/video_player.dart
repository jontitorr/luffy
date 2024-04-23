import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_displaymode/flutter_displaymode.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/api/history.dart";
import "package:luffy/components/video_player/controls.dart";
import "package:luffy/util.dart";
import "package:media_kit/media_kit.dart";
import "package:media_kit_video/media_kit_video.dart";

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.showId,
    required this.showTitle,
    required this.episode,
    required this.episodeNum,
    required this.sourceName,
    this.savedProgress,
    required this.imageUrl,
    required this.episodes,
    required this.sourceFetcher,
    this.animeId,
    required this.showUrl,
  });

  final String showId;
  final String showTitle;
  final Episode episode;
  final int episodeNum;
  final String sourceName;
  final double? savedProgress;
  final String? imageUrl;
  final List<Episode> episodes;
  final Future<List<VideoSource>> Function(Episode) sourceFetcher;
  final int? animeId;
  final String showUrl;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  BoxFit _fit = BoxFit.contain;
  bool _isBuffering = true;
  bool _isPlaying = false;
  Duration _buffered = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _speed = 1.0;
  bool _hasResumed = false;
  VideoSource? _currentSource;
  List<VideoSource>? _sources;
  Subtitle? _currentSubtitle;
  List<Subtitle?>? _subtitles;
  double? _subtitleOffset;
  Duration _positionBeforeSourceChange = Duration.zero;
  bool _hasResumedFromSourceChange = true;
  late int _currentEpisodeNum = widget.episodeNum;
  bool _isRequestInProgress = false;

  void _onRewind() {
    _player.seek(
      Duration(
        milliseconds: (_position.inMilliseconds - 10000).clamp(
          0,
          _duration.inMilliseconds,
        ),
      ),
    );
  }

  void _onPlayPause() {
    _isPlaying ? _player.pause() : _player.play();
  }

  void _onFastForward() {
    _player.seek(
      Duration(
        milliseconds: (_position.inMilliseconds + 10000).clamp(
          0,
          _duration.inMilliseconds,
        ),
      ),
    );
  }

  void _onProgressChanged(Duration position) {
    _player.seek(position);
  }

  void _onFitChanged(BoxFit fit) {
    setState(() {
      _fit = fit;
    });
  }

  void _onSpeedChanged(double speed) {
    _player.setRate(speed);
  }

  void _onSubtitleOffsetChanged(double subtitleOffset) {
    setState(() {
      _subtitleOffset = subtitleOffset;
    });
  }

  void _onSourceChanged(VideoSource source) {
    prints("VideoPlayer source changed to ${source.description}");

    _player.open(
      Media(
        source.videoUrl,
      ),
    );

    setState(() {
      _positionBeforeSourceChange = _position;
      _hasResumedFromSourceChange = false;
    });
  }

  void _onSubtitleChanged(Subtitle? subtitle) {
    setState(() {
      _currentSubtitle = subtitle;

      if (subtitle != null) {
        _subtitleOffset = 0.0;
      }
    });
  }

  void _onEpisodeNumChanged(int episodeNum) {
    if (!mounted || _isRequestInProgress) {
      return;
    }

    prints(
      "VideoPlayer episode changed to ${widget.episodes[episodeNum].title}",
    );

    _currentEpisodeNum = episodeNum;
    _isRequestInProgress = true;

    setState(() {
      _positionBeforeSourceChange = Duration.zero;
      _hasResumedFromSourceChange = false;
      _isBuffering = true;
    });

    _player.stop();

    // Really long network request.
    widget
        .sourceFetcher(
      widget.episodes[episodeNum],
    )
        .then((sources) {
      if (!mounted) {
        return;
      }

      if (sources.isEmpty) {
        prints(
          "No sources found for ${widget.showTitle} episode $episodeNum",
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No sources found for ${widget.showTitle} episode $episodeNum",
            ),
          ),
        );

        Navigator.pop(context);

        return;
      }

      setState(() {
        _currentSource = sources.first;
        _currentSubtitle = sources.first.subtitle;

        if (_currentSubtitle != null) {
          _subtitleOffset = 0.0;
        }

        _sources = sources;
        _subtitles = sources.map((source) => source.subtitle).toList();
        _isRequestInProgress = false;
      });

      _player.open(
        Media(
          sources[0].videoUrl,
        ),
      );
    });
  }

  void _syncProgress() {
    final pos = _position.inMilliseconds;
    final dur = _duration.inMilliseconds;
    final progress = (pos / dur).clamp(0.0, 1.0);

    if (!progress.isFinite || pos == 0) {
      return;
    }

    prints("Watched enough of the video to save progress.");

    final currentEpisode = widget.episodes[_currentEpisodeNum];

    HistoryService.addProgress(
      HistoryEntry(
        id: widget.showId,
        animeId: widget.animeId,
        title: widget.showTitle,
        imageUrl: currentEpisode.thumbnailUrl ?? "",
        progress: {},
        totalEpisodes: widget.episodes.length,
        sources: {
          _currentEpisodeNum: _sources ?? [],
        },
        subtitles: {
          widget.episodeNum: _subtitles?.whereType<Subtitle>().toList() ?? [],
        },
        sourceExpiration: DateTime.now().add(const Duration(hours: 1)),
        showUrl: widget.showUrl,
      ),
      _currentEpisodeNum,
      progress,
    );

    prints(
      "Saved video progress for episode $_currentEpisodeNum | Progress: $progress",
    );
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      FlutterDisplayMode.setLowRefreshRate();
    }

    Future.microtask(() async {
      // Look up the history and see if the sources' lastSourceUpdated is within 1 hour.
      final history = await HistoryService.getMedia(widget.showId);

      final sources = await (() async {
        if (history != null &&
            history.sources.containsKey(widget.episodeNum) &&
            history.sources[widget.episodeNum]!.isNotEmpty &&
            history.sourceExpiration.isAfter(DateTime.now())) {
          prints(
            "Using cached sources for ${widget.showTitle} episode ${widget.episodeNum}",
          );
          return history.sources[widget.episodeNum]!;
        }

        return widget.sourceFetcher(widget.episodes[_currentEpisodeNum]);
      })();

      // Sometimes it can take too long to fetch the sources and the user has already left the screen.
      if (!mounted) {
        return;
      }

      if (sources.isEmpty) {
        prints(
          "No sources found for ${widget.showTitle} episode ${widget.episodeNum}",
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "No sources found for ${widget.showTitle} episode ${widget.episodeNum}",
            ),
          ),
        );

        Navigator.pop(context);

        return;
      }

      setState(() {
        _currentEpisodeNum = widget.episodeNum;
        _currentSource = sources.first;
        _currentSubtitle = sources.first.subtitle;

        if (_currentSubtitle != null) {
          _subtitleOffset = 0.0;
        }

        _sources = sources;
        _subtitles = sources.map((source) => source.subtitle).toList();
      });

      _player.stream.buffering.listen((event) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isBuffering = event;

          final savedProgress = widget.savedProgress;

          if (!event &&
              !_hasResumed &&
              _duration != Duration.zero &&
              savedProgress != null) {
            prints("Seeking to $savedProgress");
            _player.seek(
              Duration(
                milliseconds:
                    (_duration.inMilliseconds * savedProgress).toInt(),
              ),
            );

            setState(() {
              _hasResumed = true;
            });
          }

          if (!event &&
              !_hasResumedFromSourceChange &&
              _duration != Duration.zero) {
            prints("Seeking to $_positionBeforeSourceChange");
            _player.seek(
              _positionBeforeSourceChange,
            );

            setState(() {
              _hasResumedFromSourceChange = true;
            });
          }
        });
      });

      _player.stream.buffer.listen((event) {
        if (!mounted) {
          return;
        }

        setState(() {
          _buffered = event;
        });
      });

      _player.stream.duration.listen((event) {
        if (!mounted) {
          return;
        }

        setState(() {
          _duration = event;
        });
      });

      _player.stream.playing.listen((event) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isPlaying = event;
        });
      });

      _player.stream.position.listen((event) {
        if (!mounted) {
          return;
        }

        setState(() {
          _position = event;
        });
      });

      _player.stream.rate.listen((event) {
        if (!mounted) {
          return;
        }

        setState(() {
          _speed = event;
        });
      });

      prints("VideoPlayer source changed to ${sources.first.videoUrl}");

      await _player.open(
        Playlist(
          sources
              .mapNotNull((it) => Media(it.videoUrl, httpHeaders: it.headers)),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        prints("VideoPlayerScreen: onWillPop");

        // Pop it manually.
        final progress = _position.inMilliseconds / _duration.inMilliseconds;

        Navigator.pop(context, progress.isFinite ? progress : null);

        return false;
      },
      child: SafeArea(
        child: Scaffold(
          body: Container(
            color: Colors.black,
            child: Stack(
              children: [
                SizedBox.expand(
                  child: FittedBox(
                    fit: _fit,
                    child: SizedBox(
                      width: _controller.rect.value?.width ??
                          MediaQuery.of(context).size.width,
                      height: _controller.rect.value?.height ??
                          MediaQuery.of(context).size.height,
                      child: Video(
                        controller: _controller,
                        controls: null,
                      ),
                    ),
                  ),
                ),
                ControlsOverlay(
                  isBuffering: _isBuffering,
                  isPlaying: _isPlaying,
                  duration: _duration,
                  position: _position,
                  buffered: _buffered,
                  size: _controller.rect.value?.size ?? Size.zero,
                  showTitle: widget.showTitle,
                  episodeTitle:
                      widget.episodes[_currentEpisodeNum].title ?? "Untitled",
                  episodeNum: _currentEpisodeNum,
                  sourceName: widget.sourceName,
                  fit: _fit,
                  speed: _speed,
                  subtitleOffset: _subtitleOffset,
                  subtitle: _currentSubtitle,
                  subtitles: _subtitles,
                  onProgressChanged: _onProgressChanged,
                  onRewind: _onRewind,
                  onPlayPause: _onPlayPause,
                  onFastForward: _onFastForward,
                  onFitChanged: _onFitChanged,
                  onSpeedChanged: _onSpeedChanged,
                  episodes: widget.episodes,
                  source: _currentSource,
                  sources: _sources,
                  onSourceChanged: _onSourceChanged,
                  onSubtitleChanged: _onSubtitleChanged,
                  onSubtitleOffsetChanged: _onSubtitleOffsetChanged,
                  onEpisodeNumChanged: _onEpisodeNumChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _syncProgress();
    _player.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      FlutterDisplayMode.setHighRefreshRate();
    }

    super.dispose();
  }
}
