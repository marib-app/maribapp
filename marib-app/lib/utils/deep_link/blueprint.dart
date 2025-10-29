
import 'package:marib/utils/deep_link/nativeDeepLinkManager.dart';

abstract class NativeDeepLinkUtility {
  void handle(Uri uri, ProcessResult? result);
  Future<void> handleLink(String url) async {
    Uri parse = Uri.parse(url);

    NativeDeepLinkManager nativeDeepLinkManager = NativeDeepLinkManager();
    ProcessResult? processResult = await nativeDeepLinkManager.process(parse);
    nativeDeepLinkManager.handle(parse, processResult);
  }

  /*AppPageRoute.build(RouteSettings settings) {
    return AppPageRoute.build(
      builder: (context) {
        return NativeLinkWidget(
          settings: settings,
        );
      },
    );
  }*/

  Future<ProcessResult?> process(Uri uri);
}

class ProcessResult<T> {
  final T result;
  ProcessResult(this.result);
}
