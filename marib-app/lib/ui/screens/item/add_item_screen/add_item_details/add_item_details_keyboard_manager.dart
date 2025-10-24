import 'package:flutter/material.dart';

class AddItemDetailsKeyboardManager {
  AddItemDetailsKeyboardManager({
    required ScrollController formScrollController,
  }) : _formScrollController = formScrollController;

  final ScrollController _formScrollController;

  BuildContext? _lastFocusedContext;
  double _lastFocusedAlignment = 0.2;
  bool _isKeyboardVisible = false;
  double _lastViewInsetsBottom = 0;

  Widget wrapWithKeyboardAwareFocus({
    required Widget child,
    double alignment = 0.2,
  }) {
    return Builder(
      builder: (context) {
        return Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              _lastFocusedContext = context;
              _lastFocusedAlignment = alignment;
              if (_formScrollController.hasClients) {
                Scrollable.ensureVisible(
                  context,
                  alignment: alignment,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                );
              }
            } else if (_lastFocusedContext == context) {
              _lastFocusedContext = null;
            }
          },
          child: child,
        );
      },
    );
  }

  void handleMetricsChanged(State state) {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final double viewInsetsBottom = dispatcher.views.isNotEmpty
        ? dispatcher.views.first.viewInsets.bottom
        : dispatcher.implicitView?.viewInsets.bottom ?? 0.0;

    final bool isVisible = viewInsetsBottom > 0;
    if (!isVisible) {
      _isKeyboardVisible = false;
      _lastViewInsetsBottom = 0;
      return;
    }

    const double threshold = 16.0;
    final bool changedSignificantly =
        (viewInsetsBottom - _lastViewInsetsBottom).abs() > threshold;
    final bool shouldScroll = !_isKeyboardVisible || changedSignificantly;

    _isKeyboardVisible = true;
    _lastViewInsetsBottom = viewInsetsBottom;

    if (!shouldScroll) {
      return;
    }

    if (_lastFocusedContext == null || !_formScrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.mounted) {
        return;
      }
      final BuildContext? targetContext = _lastFocusedContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        alignment: _lastFocusedAlignment,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }
}