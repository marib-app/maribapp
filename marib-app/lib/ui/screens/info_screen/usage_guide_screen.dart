import 'package:flutter/material.dart';
import 'package:marib/ui/screens/classified_ads/app_html.dart';
import 'package:marib/ui/screens/widgets/animated_routes/blur_page_route.dart';
import 'package:marib/ui/theme/theme.dart';
import 'package:marib/utils/extensions/extensions.dart';
import 'package:marib/utils/ui_utils.dart';
import 'package:webview_flutter/webview_flutter.dart';

class UsageGuideScreen extends StatefulWidget {
  const UsageGuideScreen({
    super.key,
    required this.title,
    this.htmlContent,
    required this.fallbackUri,
  });

  final String title;
  final String? htmlContent;
  final Uri fallbackUri;

  static Route route({
    required String title,
    String? htmlContent,
    required Uri fallbackUri,
  }) {
    return BlurredRouter(
      builder: (_) => UsageGuideScreen(
        title: title,
        htmlContent: htmlContent,
        fallbackUri: fallbackUri,
      ),
    );
  }

  @override
  State<UsageGuideScreen> createState() => _UsageGuideScreenState();
}

class _UsageGuideScreenState extends State<UsageGuideScreen> {
  WebViewController? _webViewController;
  bool _isLoading = false;
  bool _hasError = false;

  bool get _hasInlineHtml =>
      widget.htmlContent != null && widget.htmlContent!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_hasInlineHtml) {
      _initializeWebView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryColor,
      appBar: UiUtils.buildAppBar(
        context,
        title: widget.title,
        showBackButton: true,
      ),
      body: _hasInlineHtml ? _buildHtmlContent() : _buildFallbackContent(),
    );
  }

  Widget _buildHtmlContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: AppHtml(
        data: widget.htmlContent!,
        baseUrl: widget.fallbackUri.toString(),
        centerContent: true,
        maxWidth: 720,
        preserveInlineStyles: true,
        selectable: true,
        outerPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildFallbackContent() {
    return Stack(
      children: <Widget>[
        if (!_hasError && _webViewController != null)
          WebViewWidget(controller: _webViewController!),
        if (_isLoading)
          Center(
            child: UiUtils.progress(
              normalProgressColor: context.color.territoryColor,
            ),
          ),
        if (_hasError)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    "somethingWentWrong".translate(context),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _retryFallback,
                    child: Text("retry".translate(context)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _initializeWebView() {
    _isLoading = true;
    _hasError = false;
    _webViewController = _createWebViewController();
  }

  WebViewController _createWebViewController() {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
        ),
      )
      ..loadRequest(widget.fallbackUri);
  }

  void _retryFallback() {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
      _webViewController = _createWebViewController();
    });
  }
}