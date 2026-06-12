import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// In-app Wayl checkout.
///
/// Opens the Wayl payment URL inside a WebView instead of an external browser,
/// so we can detect the post-payment redirect back to our own domain and pop
/// the screen automatically — the user never lands on a web page and never has
/// to switch back to the app manually.
///
/// Detection contract: Wayl + the bank's 3DS pages live on Wayl / bank domains.
/// The ONLY navigation to `mulhimiq.com` happens when Wayl redirects to our
/// `redirectionUrl` after the payment flow ends (success OR cancel). We treat
/// that navigation as "flow finished", pop with `true`, and let the caller
/// re-fetch the real status from the API (the webhook is the source of truth) —
/// we never trust the redirect URL itself for the payment result.
///
/// Returns `true`  → the flow reached our redirect (caller should refresh).
/// Returns `false` → the user closed the screen before finishing.
class WaylPaymentScreen extends StatefulWidget {
  const WaylPaymentScreen({
    super.key,
    required this.url,
    this.returnHosts = const ['mulhimiq.com', 'www.mulhimiq.com', 'api.mulhimiq.com'],
    this.title = 'إتمام الدفع',
  });

  final String url;
  final List<String> returnHosts;
  final String title;

  @override
  State<WaylPaymentScreen> createState() => _WaylPaymentScreenState();
}

class _WaylPaymentScreenState extends State<WaylPaymentScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _done = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (req) {
            if (_isReturnUrl(req.url)) {
              _finish();
              return NavigationDecision.prevent;
            }
            // Payment pages are web (http/https). Block every other scheme —
            // `javascript:`, `file:`, `data:`, `intent:` and app-handoff
            // schemes — so a crafted gateway response can't run a local script,
            // read device files, or jump out to an arbitrary app.
            final scheme = Uri.tryParse(req.url)?.scheme.toLowerCase() ?? '';
            if (scheme != 'http' && scheme != 'https') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (_isReturnUrl(url)) {
              _finish();
              return;
            }
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            // Surface a hard load/TLS failure instead of a blank WebView.
            if (mounted && err.isForMainFrame == true) {
              setState(() {
                _loading = false;
                _error = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  bool _isReturnUrl(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return widget.returnHosts.any((h) => host == h);
  }

  void _finish() {
    if (_done) return;
    _done = true;
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: _error
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'تعذّر تحميل صفحة الدفع. تحقّق من الاتصال وحاول مجدداً.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _error = false;
                            _loading = true;
                          });
                          _controller.loadRequest(Uri.parse(widget.url));
                        },
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_loading) const LinearProgressIndicator(minHeight: 3),
                ],
              ),
      ),
    );
  }
}
