part of "../chat_widget.dart";

class RecordMessage extends StatefulWidget {
  final String url;
  final bool isSentByMe;
  const RecordMessage({super.key, required this.url, required this.isSentByMe});

  @override
  State<RecordMessage> createState() => _RecordMessageState();
}

class _RecordMessageState extends State<RecordMessage> {
  AudioPlayer audioPlayer = AudioPlayer();
  bool isPlaying = false;
  int position = 0;
  int durationChanged = 0;

  bool isLoading = false;

  String _formatSeconds(int seconds) {
    final int clamped = seconds < 0 ? 0 : seconds;
    final int minutes = clamped ~/ 60;
    final int remainingSeconds = clamped % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    audioPlayer.onDurationChanged.listen((Duration event) {
      durationChanged = event.inSeconds;

      if (isLoading && durationChanged > 0) {
        isLoading = false;
      }

      setState(() {});
    });

    audioPlayer.onPlayerStateChanged.listen((PlayerState event) {
      isPlaying = event == PlayerState.playing;

      if (event != PlayerState.playing) {
        isLoading = false;
      }

      setState(() {});
    });
    audioPlayer.onPositionChanged.listen((Duration event) {
      position = event.inSeconds;
      setState(() {});
    });

    audioPlayer.onPlayerComplete.listen((event) {
      position = durationChanged;
      isPlaying = false;
      isLoading = false;
      setState(() {});
    });

    // audioPlayer.seek(const Duration(seconds: 1));

    super.initState();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxSliderValue =
        durationChanged == 0 ? 1 : durationChanged.toDouble();
    final double sliderValue = position
        .clamp(0, durationChanged == 0 ? position : durationChanged)
        .toDouble();

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        GestureDetector(
            onTap: () async {
              if (!isPlaying) {
                setState(() {
                  isLoading = true;
                });
                final bool isRemote = widget.url.startsWith('http') ||
                    widget.url.startsWith('https');
                final Source source = isRemote
                    ? UrlSource(widget.url)
                    : DeviceFileSource(widget.url);
                try {
                  await audioPlayer.play(source);
                } catch (_) {
                  if (mounted) {
                    setState(() {
                      isLoading = false;
                    });
                  }
                  audioPlayer.stop();
                }
              } else {
                await audioPlayer.stop();
              }
            },
            child: isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isSentByMe
                              ? context.color.primaryColor
                              : context.color.territoryColor),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: widget.isSentByMe
                        ? context.color.primaryColor
                        : context.color.territoryColor,
                  )),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            activeColor: widget.isSentByMe
                ? context.color.primaryColor
                : context.color.territoryColor,
            inactiveColor: widget.isSentByMe
                ? context.color.primaryColor.withOpacity(0.3)
                : context.color.territoryColor.withOpacity(0.3),
            value: sliderValue,
            onChanged: durationChanged == 0
                ? null
                : (v) {
                    audioPlayer.seek(Duration(seconds: v.toInt()));
                    position = v.toInt();
                    setState(() {});
                  },
            min: 0,
            max: maxSliderValue,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "${_formatSeconds(position)} / ${_formatSeconds(durationChanged)}",
        ).color(widget.isSentByMe
            ? context.color.primaryColor
            : context.color.textColorDark),
      ],
    );
  }
}
