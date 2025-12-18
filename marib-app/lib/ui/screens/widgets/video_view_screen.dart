import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'package:marib/ui/theme/theme.dart';
import 'package:marib/ui/screens/widgets/youtube_player_widget.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/helper_utils.dart';

class VideoViewScreen extends StatefulWidget {
  final String videoUrl;
  final FlickManager? flickManager;
  const VideoViewScreen({
    super.key,
    required this.videoUrl,
    this.flickManager,
  });

  @override
  State<VideoViewScreen> createState() => _VideoViewScreenState();
}

class _VideoViewScreenState extends State<VideoViewScreen> {
  late final FlickManager _flickManager;
  late final bool _ownsManager;
  bool _invalidVideo = false;

  @override
  void initState() {
    super.initState();
    if (widget.flickManager != null) {
      _flickManager = widget.flickManager!;
      _ownsManager = false;
    } else {
      _ownsManager = true;
      try {
        _flickManager = FlickManager(
          videoPlayerController:
              VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl)),
          autoInitialize: true,
        );
      } catch (_) {
        _invalidVideo = true;
        _flickManager = FlickManager(
          videoPlayerController: VideoPlayerController.network(''),
        );
      }
    }
  }

  @override
  void dispose() {
    if (_ownsManager) {
      _flickManager.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = context.color.backgroundColor;
    return SafeArea(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: true,
          iconTheme: IconThemeData(color: context.color.territoryColor),
        ),
        backgroundColor: bg,
        body: Center(
          child: HelperUtils.checkVideoType(
            widget.videoUrl,
            onYoutubeVideo: () {
              return YoutubePlayerWidget(
                videoUrl: widget.videoUrl,
                onLandscape: () {},
                onPortrate: () {},
                enableCaptions: false,
              );
            },
            onOtherVideo: () {
              if (_invalidVideo) {
                return _buildError(context);
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio:
                        _flickManager.flickVideoManager?.videoPlayerValue?.aspectRatio ??
                            16 / 9,
                    child: FlickVideoPlayer(
                      flickManager: _flickManager,
                      preferredDeviceOrientation: const [
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.landscapeLeft,
                        DeviceOrientation.landscapeRight,
                      ],
                      flickVideoWithControls: const FlickVideoWithControls(
                        controls: FlickPortraitControls(
                          iconSize: 24,
                          fontSize: 13,
                        ),
                      ),
                      flickVideoWithControlsFullscreen:
                          const FlickVideoWithControls(
                        controls: FlickLandscapeControls(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 8),
        Text(
          'video_unavailable'.translate(context),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: context.color.textDefaultColor),
        ),
      ],
    );
  }
}
