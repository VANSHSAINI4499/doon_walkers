import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Attempts to open [urlString] in an external app/browser.
///
/// On failure — unparseable URL, no app installed to handle it, launch
/// rejected by the platform — shows a SnackBar with the raw URL instead
/// of failing silently. A dead link should be visible, not swallowed.
Future<void> openExternalLink(BuildContext context, String urlString) async {
  final uri = Uri.tryParse(urlString);
  if (uri == null) {
    _showFallback(context, urlString);
    return;
  }

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      _showFallback(context, urlString);
    }
  } catch (_) {
    if (context.mounted) {
      _showFallback(context, urlString);
    }
  }
}

void _showFallback(BuildContext context, String urlString) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Could not open link: $urlString')),
  );
}
