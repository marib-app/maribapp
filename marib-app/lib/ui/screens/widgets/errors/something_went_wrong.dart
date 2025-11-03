import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:marib/app/navigation/app_page_route.dart';
import 'package:marib/app/navigation/motion/route_motion.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';


class SomethingWentWrong extends StatelessWidget {
  final FlutterErrorDetails? error;
  final VoidCallback? onReload;
  final String? title;
  final String? description;
  final String? details;
  final String? actionLabel;
  final IconData? icon;


  const SomethingWentWrong({
    super.key,
    this.error,
    this.onReload,
    this.title,
    this.description,
    this.details,
    this.actionLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.color;

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    final String resolvedTitle = title ?? 'somethingWentWrong'.translate(context);
    final String resolvedDescription = description ??
        'تعذر إكمال العملية حالياً. حاول مرة أخرى بعد قليل أو تواصل مع فريق الدعم عند تكرار المشكلة.';
    final String? rawDetails = (details ?? error?.exceptionAsString())?.trim();
    final String? resolvedDetails =
    (rawDetails == null || rawDetails.isEmpty) ? null : rawDetails;
    final IconData resolvedIcon = icon ?? Icons.error_outline_rounded;
    final String resolvedActionLabel =
        actionLabel ?? 'retry'.translate(context);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
          Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: palette.territoryColor.withOpacity(0.1),
            shape: BoxShape.circle,
                ),
          child: Icon(
            resolvedIcon,
            size: 56,
            color: palette.territoryColor,
                ),
              ),
                const SizedBox(height: 20),
                Text(
                  resolvedTitle,
                  textAlign: TextAlign.center,
                )
                    .size(context.font.extraLarge)
                    .color(onSurface)
                    .bold(weight: FontWeight.w700),
                const SizedBox(height: 12),
                Text(
                  resolvedDescription,
                  textAlign: TextAlign.center,
                ).size(context.font.large).color(onSurface.withOpacity(0.75)),
                if (resolvedDetails != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.borderColor),
                    ),
                    child: SelectableText(
                      resolvedDetails,
                      textAlign: TextAlign.center,
                  ),
                  ),
                ],
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
                    child: Text(resolvedActionLabel)
                        .size(context.font.large)
                        .bold(weight: FontWeight.w600),
                  ),
                ],
              ],
          ),
        ),
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
      AppPageRoute.build(
        builder: (context) => ErrorDetailScreen(stackLines: filteredStackLines),
        motionPattern: AppMotionPattern.glide,
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


