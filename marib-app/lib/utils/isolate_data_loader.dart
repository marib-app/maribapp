import 'dart:async';
import 'dart:isolate';

class IsolateDataLoader<T> {
  final Future<T> Function() _loadingFunction;

  IsolateDataLoader({
    required Future<T> Function() loadingFunction,
  }) : _loadingFunction = loadingFunction;

  Future<T> load() async {
    final ReceivePort receivePort = ReceivePort("Receive");
    final isolate = await Isolate.spawn(
      _isolateEntryPoint,
      receivePort.sendPort,
      debugName: "DataLoaderIsolate",
    );

    final completer = Completer<T>();
    StreamSubscription<dynamic>? subscription;
    var cleanedUp = false;

    Future<void> cleanup() async {
      if (cleanedUp) {
        return;
      }
      cleanedUp = true;


      receivePort.close();
      isolate.kill(priority: Isolate.immediate);
      final currentSubscription = subscription;
      if (currentSubscription != null) {
        await currentSubscription.cancel();
      }
    }

    subscription = receivePort.listen(
          (message) async {
        if (message is SendPort) {
          // Handshake: transfer the deferred loading function to the isolate.
          // Cleanup must wait until a real payload (result or error) arrives;
          // otherwise we'd terminate the isolate immediately and never see it.
          message.send(_loadingFunction);
        } else if (message is T) {
          if (!completer.isCompleted) {
            completer.complete(message);
          }
          await cleanup();
        } else {
          if (!completer.isCompleted) {
            if (message is List &&
                message.length == 2 &&
                message[1] is StackTrace) {
              completer.completeError(message[0], message[1] as StackTrace);
            } else if (message is List &&
                message.length == 2 &&
                message[1] is String) {
              completer.completeError(
                message[0],
                StackTrace.fromString(message[1] as String),
              );
            } else {
              completer.completeError(message);
            }
          }
          await cleanup();
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Isolate closed before delivering a result.'),
          );
        }
        unawaited(cleanup());
      },
    );

    return completer.future;
  }

  static void _isolateEntryPoint(SendPort sendPort) {
    final port = ReceivePort();
    sendPort.send(port.sendPort);
    port.listen((message) async {
      try {


        final Function loadingFunction = message as Function;

        var result = await loadingFunction();
        sendPort.send(result);
      } catch (error, stackTrace) {
        sendPort.send([error, stackTrace]);
      }
    });
  }
}
