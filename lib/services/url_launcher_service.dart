import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {
  static Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw 'آدرس نامعتبر است.';
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'امکان بازکردن لینک وجود ندارد.';
    }
  }
}
