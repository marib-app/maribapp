import 'package:lottie/lottie.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:flutter/material.dart';

class SomethingWentWrong extends StatelessWidget {
  final FlutterErrorDetails? error;

  const SomethingWentWrong({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset(
        'assets/lottie/no_internet.json', // Replace with your Lottie file path
        width: 200, // Adjust the width as needed
        height: 200, // Adjust the height as needed
        fit: BoxFit.fill, // Adjust the fit if necessary
      ),
    );
    // UiUtils.getSvg(
    //   AppIcons.somethingWentWrong,
    // ),
    // );
  }
}

class NoChatFound extends StatelessWidget {
  const NoChatFound({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        //crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // UiUtils.getSvg(
          //   AppIcons.no_chat_found,
          // ),

          Lottie.asset(
            'assets/lottie/no_chat.json', // Replace with your Lottie file path
            width: 200, // Adjust the width as needed
            height: 200, // Adjust the height as needed
            fit: BoxFit.fill, // Adjust the fit if necessary
          ),
          const SizedBox(
            height: 20,
          ),
          Text("nodatafound".translate(context))
              .size(context.font.larger)
              .color(context.color.territoryColor)
              .bold(weight: FontWeight.w600),
        ],
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
