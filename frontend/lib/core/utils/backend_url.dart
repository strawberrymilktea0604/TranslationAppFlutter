String? resolveBackendUrl(String? url, {required String apiBaseUrl}) {
  if (url == null) return null;

  final value = url.trim();
  if (value.isEmpty) return null;

  final parsedUrl = Uri.tryParse(value);
  final parsedBaseUrl = Uri.tryParse(apiBaseUrl.trim());
  final baseOrigin = _originFromApiBaseUrl(parsedBaseUrl);

  if (parsedUrl != null && parsedUrl.hasScheme) {
    if (_isLocalhost(parsedUrl) && parsedUrl.path.startsWith('/api/v1/')) {
      return baseOrigin == null
          ? parsedUrl.path
          : '$baseOrigin${parsedUrl.path}';
    }

    return value;
  }

  if (!value.startsWith('/')) {
    return value;
  }

  return baseOrigin == null ? value : '$baseOrigin$value';
}

String? _originFromApiBaseUrl(Uri? uri) {
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }

  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

bool _isLocalhost(Uri uri) {
  return uri.host == 'localhost' ||
      uri.host == '127.0.0.1' ||
      uri.host == '10.0.2.2';
}
