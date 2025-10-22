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

class _AutoScrollTextState extends State<AutoScrollText> {
  final _ctrl = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickoff());
  }

  void _kickoff() {
    if (!_ctrl.hasClients) return;
    if (_ctrl.position.maxScrollExtent <= 0) return;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_ctrl.hasClients) return;
      await _ctrl.animateTo(
        _ctrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_ctrl.hasClients) return;
      await _ctrl.animateTo(
        0,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
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