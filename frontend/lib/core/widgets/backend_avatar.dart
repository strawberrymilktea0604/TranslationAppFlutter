import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:frontend/core/utils/backend_url.dart';

class BackendAvatar extends StatelessWidget {
  final String? url;
  final String apiBaseUrl;
  final double radius;
  final Color? backgroundColor;
  final Widget fallback;

  const BackendAvatar({
    super.key,
    required this.url,
    required this.apiBaseUrl,
    required this.radius,
    required this.fallback,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveBackendUrl(url, apiBaseUrl: apiBaseUrl);
    final size = radius * 2;

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: resolvedUrl == null
          ? fallback
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: resolvedUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => SizedBox(
                  width: size,
                  height: size,
                  child: Center(
                    child: SizedBox(
                      width: radius * 0.55,
                      height: radius * 0.55,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => fallback,
              ),
            ),
    );
  }
}
