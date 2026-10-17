import 'package:url_launcher/url_launcher.dart';

/// Opens an outside link in a new tab (web) or the browser (mobile).
Future<bool> openLink(String url) async {
  final uri = Uri.tryParse(url);
  final web = uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  if (!web) return false;
  return launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
