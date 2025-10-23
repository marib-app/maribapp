import 'dart:async';

import 'package:flutter/material.dart';

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double gap;

  const AutoScrollText({
    super.key,
    required this.text,
    this.style,
    this.gap = 40,
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText>
    with WidgetsBindingObserver {
  final _ctrl = ScrollController();
  Timer? _timer;
  bool _isLifecycleResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final AppLifecycleState? lifecycleState =
        WidgetsBinding.instance.lifecycleState;
    _isLifecycleResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;

    WidgetsBinding.instance.addPostFrameCallback((_) => _kickoffIfActive());
  }

  void _kickoffIfActive() {
    if (!_isLifecycleResumed) {
      return;
    }
    _kickoff();
  }

  void _kickoff() {
    if (!_isLifecycleResumed) return;
    if (!_ctrl.hasClients) return;
    if (_ctrl.position.maxScrollExtent <= 0) return;

    _cancelTimer();

    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_isLifecycleResumed) return;
      if (!_ctrl.hasClients) return;
      await _ctrl.animateTo(
        _ctrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
      );
      if (!_isLifecycleResumed) return;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_ctrl.hasClients) return;
      await _ctrl.animateTo(
        0,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
      );
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTimer();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool shouldResume = state == AppLifecycleState.resumed;
    if (shouldResume == _isLifecycleResumed) {
      return;
    }
    _isLifecycleResumed = shouldResume;
    if (shouldResume) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _kickoff();
      });
    } else {
      _cancelTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style, maxLines: 1),
          SizedBox(width: widget.gap),
          Text(widget.text, style: widget.style, maxLines: 1),
        ],
      ),
    );
  }
}
