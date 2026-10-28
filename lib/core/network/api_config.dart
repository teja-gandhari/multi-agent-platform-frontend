class ApiConfig {
  ApiConfig._();

  /// Default API base URL. Can be overridden at compile time:
  /// flutter run -d chrome --dart-define=API_BASE_URL=http://15.134.215.0:8000
  static const String _defaultBaseUrl = 'https://3-105-199-45.sslip.io';

  static String? _customBaseUrl;

  /// Get the normalized base URL without trailing slash.
  static String get baseUrl {
    final raw = _customBaseUrl ??
        const String.fromEnvironment('API_BASE_URL',
            defaultValue: _defaultBaseUrl);
    return _cleanUrl(raw);
  }

  /// Allow runtime override (e.g. settings dialog).
  static set customBaseUrl(String? value) {
    _customBaseUrl = value != null ? _cleanUrl(value) : null;
  }

  /// Strip trailing slash
  static String _cleanUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Build an HTTP/HTTPS Uri
  static Uri buildUri(String path, [Map<String, String>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$cleanPath').replace(queryParameters: query);
  }

  /// Build a WebSocket Uri for a project
  static Uri buildWsUri(String projectId, String token) {
    final base = baseUrl;
    final wsScheme = base.startsWith('https://') ? 'wss://' : 'ws://';
    final hostAndPort = base.replaceFirst(RegExp(r'^https?://'), '');
    return Uri.parse('$wsScheme$hostAndPort/ws/$projectId?token=$token');
  }

  /// Resolve an application URL (e.g. http://127.0.0.1:8080) to the backend's host
  /// if the backend is running on a remote host (e.g. EC2 public IP or domain).
  static String resolveAppUrl(String rawUrl) {
    if (rawUrl.isEmpty) return rawUrl;
    try {
      final parsed = Uri.parse(rawUrl);
      final currentBase = Uri.parse(baseUrl);
      if (currentBase.host.isNotEmpty &&
          currentBase.host != '127.0.0.1' &&
          currentBase.host != 'localhost') {
        if (parsed.host == '127.0.0.1' || parsed.host == 'localhost') {
          return parsed
              .replace(
                scheme: 'https',
                host: currentBase.host,
                port: parsed.port == 8080 ? 8443 : parsed.port,
              )
              .toString();
        }
      }
    } catch (_) {}
    return rawUrl;
  }
}
