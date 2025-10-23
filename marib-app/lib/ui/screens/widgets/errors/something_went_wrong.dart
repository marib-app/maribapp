import 'package:lottie/lottie.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SomethingWentWrong extends StatelessWidget {
  final FlutterErrorDetails? error;
  final VoidCallback? onReload;

  const SomethingWentWrong({super.key, this.error, this.onReload});

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            'assets/lottie/no_internet.json', // Replace with your Lottie file path
            width: 200, // Adjust the width as needed
            height: 200, // Adjust the height as needed
            fit: BoxFit.fill, // Adjust the fit if necessary
          ),
          if (onReload != null) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onReload,
              style: OutlinedButton.styleFrom(
                foregroundColor: onSurface,
                side: BorderSide(
                  color: onSurface.withOpacity(0.3),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'إعادة تحميل',
              ).size(context.font.large).bold(weight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
    // UiUtils.getSvg(
    //   AppIcons.somethingWentWrong,
    // ),
    // );
  }
}

class NoChatFound extends StatelessWidget {
  const NoChatFound({
    super.key,
    this.onRetry,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.icon,
    this.padding,
  });

  final VoidCallback? onRetry;
  final String? title;
  final String? subtitle;
  final String? actionLabel;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.color;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final resolvedIcon = icon ?? CupertinoIcons.chat_bubble_text;
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.32);
    final resolvedTitle = title ?? 'emptyStateChatTitle'.translate(context);
    final resolvedSubtitle =
        subtitle ?? 'emptyStateChatDescription'.translate(context);

    return Center(
      child: Padding(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                resolvedIcon,
                size: 64,
                color: iconColor,
              ),
              const SizedBox(height: 20),
              Text(
                resolvedTitle,
                textAlign: TextAlign.center,
              )
                  .size(context.font.extraLarge)
                  .color(palette.textDefaultColor)
                  .bold(weight: FontWeight.w600),
              const SizedBox(height: 10),
              Text(
                resolvedSubtitle,
                textAlign: TextAlign.center,
              )
                  .size(context.font.large)
                  .color(palette.textLightColor)
                  .centerAlign(),
              if (onRetry != null) ...[
                const SizedBox(height: 28),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 160),
                  child: OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: onSurface,
                      side: BorderSide(
                        color: onSurface.withOpacity(0.3),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      (actionLabel ?? 'retry').translate(context),
                    ).size(context.font.large).bold(weight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final StackTrace stack;

  const ErrorScreen({super.key, required this.stack});

  void _generateError(context) {
    final filteredStackLines = stack.toString().split('\n').where((line) {
      return !line.contains('package:flutter');
    }).map((line) {
      final parts = line.split(' ');
      return parts.length > 1 ? parts[1] : line;
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ErrorDetailScreen(stackLines: filteredStackLines),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        _generateError(context);
      },
      child: const Text('Generate Error'),
    );
  }
}

class ErrorDetailScreen extends StatelessWidget {
  final List<String> stackLines;

  const ErrorDetailScreen({super.key, required this.stackLines});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtered and Prettified Error Stack Trace'),
      ),
      body: ListView.builder(
        itemCount: stackLines.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(_formatStackTraceLine(stackLines[index])),
          );
        },
      ),
    );
  }
}

String _formatStackTraceLine(String line) {
  // Example format: "at Class.method (file.dart:42:23)"
  final startIndex = line.indexOf('at ') + 3;
  final endIndex = line.lastIndexOf('(');
  return line.substring(startIndex, endIndex);
}
