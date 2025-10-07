import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebView extends StatefulWidget {
  final String authorizationUrl;
  final String? reference;
  final Function(String) onSuccess;
  final Function(String) onFailed;
  final Function() onCancel;

  const PaymentWebView({
    Key? key,
    required this.authorizationUrl,
    this.reference,
    required this.onSuccess,
    required this.onFailed,
    required this.onCancel,
  }) : super(key: key);

  @override
  _PaymentWebViewState createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  bool _isProcessing = false; // لمنع المعالجة المتكررة

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onNavigationRequest: (NavigationRequest request) {
            final uri = request.url;
            print("uri***${uri.toString()}");

            // منع المعالجة المتكررة
            if (_isProcessing) {
              return NavigationDecision.prevent;
            }

            if (uri.contains("Completed") ||
                uri.contains("completed") ||
                uri.toLowerCase().contains("success")) {
              _isProcessing = true;
              widget.onSuccess(widget.reference ?? '');
              _closeWebView();
              return NavigationDecision.prevent;
            } else if (uri.contains("Failed") || uri.contains("failed")) {
              _isProcessing = true;
              widget.onFailed(widget.reference ?? '');
              _closeWebView();
              return NavigationDecision.prevent;
            } else {
              return NavigationDecision.navigate;
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  // دالة منفصلة لإغلاق WebView بطريقة آمنة
  void _closeWebView() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    // تنظيف الذاكرة عند التخلص من WebView
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (!_isProcessing) {
              widget.onCancel();
              _closeWebView();
            }
          },
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
