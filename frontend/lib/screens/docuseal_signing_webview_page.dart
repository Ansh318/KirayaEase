import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app DocuSeal signing (landlord or any party) using the official embed URL.
class DocusealSigningWebViewPage extends StatefulWidget {
  final String signingUrl;
  final String title;

  const DocusealSigningWebViewPage({
    super.key,
    required this.signingUrl,
    this.title = 'Sign document',
  });

  @override
  State<DocusealSigningWebViewPage> createState() =>
      _DocusealSigningWebViewPageState();
}

class _DocusealSigningWebViewPageState extends State<DocusealSigningWebViewPage> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    final uri = Uri.tryParse(widget.signingUrl.trim());
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );
    if (uri != null && uri.hasScheme) {
      _controller.loadRequest(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(widget.signingUrl.trim());
    if (uri == null || !uri.hasScheme) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('Invalid signing link.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1AAE9F),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF1AAE9F),
            ),
        ],
      ),
    );
  }
}
