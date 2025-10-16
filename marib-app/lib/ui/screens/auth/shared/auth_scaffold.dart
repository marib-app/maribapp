import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:marib/app/app_theme.dart';

import 'package:marib/utils/extensions/extensions.dart';

class AuthScaffold extends StatelessWidget {
  final Widget body;
  final Widget? header;
  final List<Widget> footer;
  final EdgeInsets padding;

  const AuthScaffold({
    super.key,
    required this.body,
    this.header,
    this.footer = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final baseColor = context.color.backgroundColor;
    final overlay = brightness == Brightness.dark
        ? Colors.black.withOpacity(0.25)
        : Colors.white.withOpacity(0.55);
    final gradientBottom = Color.alphaBlend(overlay, baseColor);

    final overlayStyle = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [baseColor, gradientBottom],
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final content = <Widget>[];
                  if (header != null) {
                    content
                      ..add(header!)
                      ..add(const SizedBox(height: 24));
                  }
                  content.add(body);
                  if (footer.isNotEmpty) {
                    content
                      ..add(const SizedBox(height: 24))
                      ..addAll(footer);
                  }

                  return Center(
                    child: SingleChildScrollView(
                      padding: padding + EdgeInsets.only(bottom: bottomInset),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: content,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}