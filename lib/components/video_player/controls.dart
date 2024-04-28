import "dart:async";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_volume_controller/flutter_volume_controller.dart";
import "package:luffy/api/anime.dart";
import "package:luffy/components/progress_bar.dart";
import "package:luffy/components/slider_stepper.dart";
import "package:luffy/components/video_player/control_icon.dart";
import "package:luffy/components/video_player/source_selector.dart";
import "package:luffy/util.dart";
import "package:luffy/util/subtitle_controller.dart";
import "package:luffy/util/subtitle_view.dart";
import "package:screen_brightness/screen_brightness.dart";

class ControlsOverlay extends StatefulWidget {
  const ControlsOverlay({
    super.key,
    required this.isBuffering,
    required this.isPlaying,
    required this.duration,
    required this.position,
    required this.buffered,
    required this.size,
    required this.showTitle,
    required this.episodeTitle,
    required this.episodeNum,
    required this.sourceName,
    required this.fit,
    required this.subtitle,
    required this.subtitles,
    required this.speed,
    required this.subtitleOffset,
    required this.onProgressChanged,
    required this.onPlayPause,
    required this.onFastForward,
    required this.onRewind,
    required this.onFitChanged,
    required this.onSpeedChanged,
    required this.onSubtitleOffsetChanged,
    required this.episodes,
    required this.source,
    required this.sources,
    required this.onSourceChanged,
    required this.onSubtitleChanged,
    required this.onEpisodeNumChanged,
  });

  final bool isBuffering;
  final bool isPlaying;
  final Duration duration;
  final Duration position;
  final Duration buffered;
  final Size size;
  final String showTitle;
  final String episodeTitle;
  final int episodeNum;
  final String sourceName;
  final BoxFit fit;
  final double speed;
  final Subtitle? subtitle;
  final List<Subtitle?>? subtitles;
  final double? subtitleOffset;

  final ValueChanged<Duration> onProgressChanged;
  final void Function() onFastForward;
  final void Function() onPlayPause;
  final void Function() onRewind;
  final ValueChanged<BoxFit> onFitChanged;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<double> onSubtitleOffsetChanged;
  final List<Episode>? episodes;
  final VideoSource? source;
  final List<VideoSource>? sources;
  final ValueChanged<VideoSource> onSourceChanged;
  final ValueChanged<Subtitle?> onSubtitleChanged;
  final ValueChanged<int> onEpisodeNumChanged;

  @override
  State<ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<ControlsOverlay> {
  late double _brightness;
  late Duration _lastPosition;
  late Duration _seek;
  int _seekDelta = 0;
  late double _volume;
  bool _showControls = true;
  bool _brightnessVisible = false;
  bool _seekVisible = false;
  bool _volumeVisible = false;
  bool _controlsLocked = false;
  bool _unlockIconVisible = false;
  SubtitleController? _subtitleController;
  bool _skippedIntro = false;

  Widget _buildBrightnessIcon() {
    if (_brightness > 0.6) {
      return const Icon(Icons.brightness_high, color: Colors.white);
    }

    if (_brightness > 0.2) {
      return const Icon(Icons.brightness_medium, color: Colors.white);
    }

    return const Icon(Icons.brightness_low, color: Colors.white);
  }

  Widget _buildVolumeIcon() {
    if (_volume > 0.6) {
      return const Icon(Icons.volume_up, color: Colors.white);
    }

    if (_volume > 0.2) {
      return const Icon(Icons.volume_down, color: Colors.white);
    }

    return const Icon(Icons.volume_mute, color: Colors.white);
  }

  List<Widget> _buildBrightnessControl() {
    if (!_brightnessVisible || _controlsLocked) {
      return [];
    }

    return [
      Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.only(
            right: 0.035 * MediaQuery.of(context).size.width,
          ),
          child: SizedBox(
            height: 0.75 * MediaQuery.of(context).size.height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _buildBrightnessIcon()),
                const SizedBox(height: 24),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _brightness,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildSeekControl() {
    if (!_seekVisible || _controlsLocked) {
      return [];
    }

    final newTimeStr = formatTime(_seek);
    final deltaTime = _seek - _lastPosition;
    final deltaTimeMs = deltaTime.inMilliseconds;
    var deltaTimeStr = formatTime(deltaTime);

    if (deltaTimeMs > 0) {
      deltaTimeStr = "+$deltaTimeStr";
    } else if (deltaTimeMs < 0) {
      deltaTimeStr = "-$deltaTimeStr";
    }

    final height = MediaQuery.of(context).size.height;

    return [
      Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 0.2 * height),
          child: Text(
            "$newTimeStr [$deltaTimeStr]",
            style: const TextStyle(color: Colors.white, fontSize: 36),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildVolumeControl() {
    if (!_volumeVisible || _controlsLocked) {
      return [];
    }

    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            left: 0.035 * MediaQuery.of(context).size.width,
          ),
          child: SizedBox(
            height: 0.75 * MediaQuery.of(context).size.height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: _buildVolumeIcon()),
                const SizedBox(height: 24),
                Expanded(
                  child: RotatedBox(
                    quarterTurns: -1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _volume,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildUnlockControl() {
    final showUnlockIcon = _controlsLocked && _unlockIconVisible;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: showUnlockIcon ? 48 : 0,
          child: IntrinsicWidth(
            child: VideoPlayerIcon(
              icon: Icons.lock_outline_sharp,
              onPressed: () {
                if (!showUnlockIcon) {
                  return;
                }

                setState(() {
                  _controlsLocked = false;
                });
              },
              label: "Unlock",
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  void _toggleFit() {
    final newFit = widget.fit == BoxFit.contain
        ? BoxFit.cover
        : widget.fit == BoxFit.cover
            ? BoxFit.fill
            : BoxFit.contain;

    widget.onFitChanged(newFit);
  }

  List<Widget> _buildSubtitles() {
    final controller = _subtitleController;

    if (controller == null) {
      return [];
    }

    final height = MediaQuery.of(context).size.height;
    final showControls = _showControls && !_controlsLocked;

    return [
      Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: showControls ? 0.35 * height : 0.2 * height,
          child: Column(
            children: [
              SubtitleControlView(
                subtitleController: controller,
                inMilliseconds: widget.position.inMilliseconds,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildControls() {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final showControls = _showControls && !_controlsLocked;
    final moreEpisodes =
        widget.episodeNum < max((widget.episodes?.length ?? 0) - 1, 0);

    return Center(
      child: Stack(
        children: [
          ..._buildSubtitles(),
          AnimatedOpacity(
            opacity: showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 100),
            child: AbsorbPointer(
              absorbing: !showControls,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black54,
                      Colors.black54,
                      Colors.black54,
                      Colors.black54,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Align(
                      child: Container(
                        decoration: const BoxDecoration(
                            // border: Border.all(color: Colors.green),
                            ),
                        child: SizedBox(
                          width: 0.6 * width,
                          height: 0.25 * height,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Flexible(
                                child: IconButton(
                                  onPressed: widget.onRewind,
                                  icon: const Icon(
                                    Icons.replay_10,
                                    color: Colors.white,
                                  ),
                                  iconSize: 70,
                                ),
                              ),
                              if (widget.isBuffering)
                                const Flexible(
                                  child: SizedBox(
                                    width: 70,
                                    height: 70,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                )
                              else
                                Flexible(
                                  child: IconButton(
                                    onPressed: () {
                                      widget.onPlayPause();
                                      setState(() {
                                        _skippedIntro = false;
                                      });
                                    },
                                    icon: Icon(
                                      widget.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                    ),
                                    iconSize: 70,
                                  ),
                                ),
                              Flexible(
                                child: IconButton(
                                  onPressed: widget.onFastForward,
                                  icon: const Icon(
                                    Icons.forward_10,
                                    color: Colors.white,
                                  ),
                                  iconSize: 70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        decoration: const BoxDecoration(
                            // border: Border.all(color: Colors.green),
                            ),
                        height: _showControls ? 0.3 * height : 0,
                        duration: const Duration(milliseconds: 100),
                        curve: Curves.easeInOut,
                        child: Column(
                          children: [
                            if (!_skippedIntro)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.only(right: 8),
                                  // decoration: BoxDecoration(
                                  //   border: Border.all(
                                  //       // color: Colors.blue,
                                  //       ),
                                  // ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      VideoPlayerIcon(
                                        onPressed: () {
                                          widget.onProgressChanged(
                                            widget.position +
                                                const Duration(
                                                  seconds: 85,
                                                ),
                                          );

                                          setState(() {
                                            _skippedIntro = true;
                                          });
                                        },
                                        label: "+85",
                                        border: Border.all(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Container(
                                decoration: const BoxDecoration(
                                    // border: Border.all(color: Colors.blue),
                                    ),
                                child: ProgressBar(
                                  duration: widget.duration,
                                  position: widget.position,
                                  buffered: widget.buffered,
                                  onProgressChanged: widget.onProgressChanged,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  VideoPlayerIcon(
                                    icon: Icons.lock_open_sharp,
                                    onPressed: () {
                                      setState(() {
                                        _controlsLocked = true;
                                        _unlockIconVisible = true;
                                      });

                                      Timer(const Duration(seconds: 1), () {
                                        setState(() {
                                          _unlockIconVisible = false;
                                        });
                                      });
                                    },
                                    label: "Lock",
                                  ),
                                  VideoPlayerIcon(
                                    icon: Icons.aspect_ratio,
                                    onPressed: _toggleFit,
                                    label: "Resize",
                                  ),
                                  if (widget.subtitleOffset != null)
                                    SliderStepper(
                                      icon: Icons.subtitles,
                                      title: "Subtitle Offset",
                                      value: widget.subtitleOffset!,
                                      min: -widget.duration.inMilliseconds
                                          .toDouble(),
                                      max: widget.duration.inMilliseconds
                                          .toDouble(),
                                      minStep: 100,
                                      maxStep: 1000,
                                      labelBuilder: (offset) =>
                                          "Offset (${offset.toStringAsFixed(0)}ms)",
                                      tooltipBuilder: (offset) =>
                                          "${offset.toStringAsFixed(0)}ms",
                                      onValueChanged: (offset) {
                                        setState(() {
                                          widget.onSubtitleOffsetChanged(
                                            offset,
                                          );
                                        });
                                      },
                                    ),
                                  SliderStepper(
                                    icon: Icons.speed,
                                    title: "Speed",
                                    value: widget.speed,
                                    original: 1.0,
                                    labelBuilder: (speed) =>
                                        "Speed (${speed.toStringAsFixed(2)}x)",
                                    tooltipBuilder: (speed) =>
                                        "${(speed * 100).toStringAsFixed(0)}%",
                                    onValueChanged: widget.onSpeedChanged,
                                  ),
                                  if (widget.sources != null)
                                    VideoPlayerSourceIcon(
                                      source: widget.source!,
                                      sources: widget.sources!,
                                      subtitle: widget.subtitle,
                                      subtitles: widget.subtitles,
                                      onSourceChanged: widget.onSourceChanged,
                                      onSubtitleChanged:
                                          widget.onSubtitleChanged,
                                    ),
                                  if (moreEpisodes)
                                    VideoPlayerIcon(
                                      icon: Icons.skip_next,
                                      onPressed: () {
                                        widget.onEpisodeNumChanged(
                                          widget.episodeNum + 1,
                                        );
                                      },
                                      label: "Next Episode",
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 0.05 * height),
                        child: Column(
                          children: [
                            Text(
                              "${widget.sourceName} source ${widget.episodeNum + 1} - ${widget.size.width.round()}x${widget.size.height.round()}",
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.showTitle} "E${widget.episodeNum + 1}" ${widget.episodeTitle}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Add a back button on the top left corner of the screen.
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: 0.05 * height,
                          left: 0.0175 * width,
                        ),
                        child: IconButton(
                          onPressed: () {
                            final progress = widget.position.inMilliseconds /
                                widget.duration.inMilliseconds;

                            Navigator.pop(context, progress);
                          },
                          icon: const Icon(Icons.arrow_back),
                          iconSize: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ..._buildBrightnessControl(),
          ..._buildSeekControl(),
          ..._buildVolumeControl(),
          _buildUnlockControl(),
        ],
      ),
    );
  }

  void _onVerticalDragStart(DragStartDetails details) {
    if (_controlsLocked) {
      return;
    }

    if (details.globalPosition.dx < MediaQuery.of(context).size.width / 2) {
      setState(() {
        _brightnessVisible = true;
      });
    } else {
      setState(() {
        _volumeVisible = true;
      });
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_controlsLocked) {
      return;
    }

    final screenHalfWidth = MediaQuery.of(context).size.width / 2;
    final screenHalfHeight = MediaQuery.of(context).size.height / 2;

    if (details.globalPosition.dx < screenHalfWidth) {
      setState(() {
        _brightness =
            (_brightness - details.delta.dy / screenHalfHeight).clamp(0.0, 1.0);
      });
      ScreenBrightness().setScreenBrightness(_brightness);
    } else {
      setState(() {
        _volume =
            (_volume - details.delta.dy / screenHalfHeight).clamp(0.0, 1.0);
      });
      FlutterVolumeController.setVolume(_volume);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_controlsLocked) {
      return setState(() {
        _unlockIconVisible = !_unlockIconVisible;
      });
    }

    setState(() {
      _brightnessVisible = false;
      _seekVisible = false;
      _volumeVisible = false;
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_controlsLocked) {
      return;
    }

    setState(() {
      _lastPosition = widget.position;
      _seek = widget.position;
      _seekVisible = true;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_controlsLocked) {
      return;
    }

    // Ignore touches that come from the edges of the screen.
    if (details.globalPosition.dy < 0.1 * MediaQuery.of(context).size.height ||
        details.globalPosition.dy > 0.9 * MediaQuery.of(context).size.height) {
      return;
    }

    final area = MediaQuery.of(context).size.width;
    final durationMs = widget.duration.inMilliseconds;

    setState(() {
      _seekDelta += (details.delta.dx / area * durationMs)
          .clamp(-durationMs, durationMs)
          .round();

      prints("Seek Delta: $_seekDelta");

      _seek = Duration(
        milliseconds:
            (_seekDelta + _lastPosition.inMilliseconds).clamp(0, durationMs),
      );
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_controlsLocked) {
      return setState(() {
        _unlockIconVisible = !_unlockIconVisible;
      });
    }

    final currentPosition = widget.position;
    final noOp = (_seekDelta > 0 &&
            _seek <=
                currentPosition) || // If we already arrived at the destination
        _seekDelta.abs() <= 1 || // Barely a seek at all
        (_seekDelta < 0 && _seek >= currentPosition);

    prints("Seeking to $_seek with a delta of $_seekDelta compared to "
        "$currentPosition");

    prints("No Op: $noOp");

    if (noOp) {
      return setState(() {
        _seekDelta = 0;
        _seekVisible = false;
      });
    }

    prints("Seek: $_seek | Last Position: $_lastPosition");

    widget.onProgressChanged(_seek);

    setState(() {
      _seekDelta = 0;
      _seekVisible = false;
    });
  }

  void _onTap() {
    if (_controlsLocked) {
      return setState(() {
        _unlockIconVisible = !_unlockIconVisible;
      });
    }

    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  void initState() {
    super.initState();

    final subtitle = widget.subtitle;
    final subtitleOffset = widget.subtitleOffset;

    prints("Subtitle: $subtitle");

    if (subtitle != null) {
      _subtitleController = SubtitleController.string(
        subtitle.text,
        format: subtitle.format,
        offset: subtitleOffset?.toInt(),
      );
    }

    FlutterVolumeController.updateShowSystemUI(false);

    ScreenBrightness().current.then(
          (value) => setState(() {
            _brightness = value;
          }),
        );

    FlutterVolumeController.addListener((value) {
      if (_volumeVisible) {
        return;
      }

      setState(() {
        _volume = value;
      });
    });
  }

  @override
  void didUpdateWidget(covariant ControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.subtitle == oldWidget.subtitle &&
        widget.subtitleOffset == oldWidget.subtitleOffset) {
      return;
    }

    final subtitle = widget.subtitle;
    final subtitleOffset = widget.subtitleOffset;

    prints("Subtitle: $subtitle | Offset: ${widget.subtitleOffset}");

    if (subtitle != null) {
      _subtitleController = SubtitleController.string(
        subtitle.text,
        format: subtitle.format,
        offset: subtitleOffset?.toInt(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          // border: Border.all(
          //   color: Theme.of(context).colorScheme.primary,
          // ),
          ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onTap: _onTap,
        child: SizedBox.expand(child: _buildControls()),
      ),
    );
  }

  @override
  void dispose() {
    FlutterVolumeController.removeListener();
    super.dispose();
  }
}
