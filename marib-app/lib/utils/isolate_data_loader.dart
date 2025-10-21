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

    unawaited(completer.future.whenComplete(cleanup));

    subscription = receivePort.listen(
      (message) {
        if (message is SendPort) {
          // Handshake: transfer the deferred loading function to the isolate.
          // Cleanup must wait until a real payload (result or error) arrives;
          // otherwise we'd terminate the isolate immediately and never see it.
          message.send(_loadingFunction);
          return;
        }

        if (completer.isCompleted) {
          return;
        }

        if (message is T) {
          completer.complete(message);
          return;
        } else {
          if (message is List && message.length == 2) {
            final dynamic error = message[0];
            final dynamic traceOrString = message[1];

            if (traceOrString is StackTrace) {
              completer.completeError(error, traceOrString);
              return;
            }

            if (traceOrString is String) {
              completer.completeError(
                error,
                StackTrace.fromString(traceOrString),
              );
              return;
            }
          }
          completer.completeError(message);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Isolate closed before delivering a result.'),
          );
        }
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
