# Flutter Web Admin Dashboard Configuration

## Overview

This document describes the Flutter Web configuration for the Translation Admin Dashboard.

## Renderer Options

### CanvasKit (Production)
- **File**: `web/index.html`
- **Entry Point**: `lib/main_web.dart`
- **Renderer**: CanvasKit
- **Performance**: Better for complex UIs with many widgets
- **Benefits**:
  - Consistent rendering across all browsers
  - Better text rendering
  - Supports shaders and advanced graphics
  - More stable for admin dashboards
- **Trade-off**: Larger bundle size (~8-10MB additional)

### HTML (Development)
- **File**: `web/index_dev.html`
- **Entry Point**: `lib/main_web.dart`
- **Renderer**: HTML/Canvas
- **Performance**: Slightly slower runtime but faster compilation
- **Benefits**:
  - Smaller bundle size
  - Faster hot reload during development
  - Better browser compatibility
- **Trade-off**: Potential rendering inconsistencies

## Running the Admin Dashboard

### Development with HTML Renderer (Faster Builds)
```bash
cd frontend
flutter run -d web --target=lib/main_web.dart --web-renderer html
```

### Development with CanvasKit (Better Performance)
```bash
cd frontend
flutter run -d web --target=lib/main_web.dart --web-renderer canvaskit
```

### Production Build (CanvasKit)
```bash
cd frontend
flutter build web --target=lib/main_web.dart --web-renderer canvaskit --release
```

### Production Build (Optimized)
```bash
cd frontend
flutter build web \
  --target=lib/main_web.dart \
  --web-renderer canvaskit \
  --release \
  --dart-define=FLUTTER_WEB_USE_EXPERIMENTAL_CANVAS_TEXT=true
```

## Configuration Files

### web/index.html
- Main production entry point
- Uses CanvasKit renderer
- Optimized for admin dashboard
- Contains loading indicator

### web/index_dev.html
- Development entry point
- Uses HTML renderer for faster builds
- Includes development-specific console logging

### lib/main_web.dart
- Web-specific entry point
- Configures admin router
- Sets up theme and localization
- Initializes database and dependencies

### lib/core/router/admin_router.dart
- Admin-only routing configuration
- Separate from mobile app router
- Includes admin authentication checks
- Routes to admin pages

## Directory Structure

```
lib/
├── main_web.dart                    # Web entry point
├── core/
│   └── router/
│       └── admin_router.dart        # Admin router configuration
└── features/
    └── admin/
        ├── presentation/
        │   ├── layout/
        │   │   └── admin_layout.dart          # Sidebar + Topbar layout
        │   └── pages/
        │       ├── admin_dashboard_page.dart  # Dashboard
        │       ├── admin_users_page.dart      # User management
        │       ├── admin_translations_page.dart # Translation management
        │       └── admin_analytics_page.dart  # Analytics

web/
├── index.html               # Production (CanvasKit)
├── index_dev.html           # Development (HTML)
├── manifest.json           # Web app manifest
├── favicon.png             # Favicon
└── icons/                  # App icons
```

## Performance Optimization Tips

### 1. CanvasKit Optimization
- Use CanvasKit for production deployments
- Pre-load CanvasKit in background for faster initialization
- Cache CanvasKit bundle in service worker

### 2. Code Splitting
- Use route-based code splitting
- Lazy load admin pages
- Split analytics charts into separate bundle

### 3. Asset Optimization
- Compress images and SVGs
- Use WebP format where supported
- Serve assets with gzip compression

### 4. Network Optimization
- Enable service worker for offline capability
- Cache API responses
- Implement request debouncing

### 5. Bundle Size
Current estimates:
- Base Flutter Web: ~3-4MB
- CanvasKit: ~8-10MB
- Admin features: ~2-3MB
- **Total**: ~13-17MB (production, release mode, gzipped: ~4-5MB)

## Browser Support

Tested and supported browsers:
- ✅ Chrome/Chromium 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+
- ⚠️ IE 11 (not supported - use service worker fallback)

## Environment Variables

Set these for different environments:

### Development
```bash
export FLUTTER_WEB_DEBUG=true
export FLUTTER_ANALYSIS_SYSROOT=/path/to/flutter
```

### Production
```bash
export FLUTTER_WEB_DEBUG=false
export FLUTTER_WEB_RELEASE_MODE=true
```

## Deployment

### Nginx Configuration
```nginx
server {
    listen 80;
    server_name admin.translation-app.com;

    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name admin.translation-app.com;

    # SSL certificates
    ssl_certificate /etc/ssl/certs/admin.crt;
    ssl_certificate_key /etc/ssl/private/admin.key;

    # Root directory for Flutter build output
    root /var/www/translation-admin/web/build/web;

    # Index file
    index index.html;

    # Cache static assets (CSS, JS, images)
    location ~* \.(js|css|png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Main app - serve index.html for all non-file requests
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # API proxy (optional)
    location /api/v1 {
        proxy_pass http://backend:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Docker Deployment
See `Dockerfile.web` for web-specific Docker configuration.

## Troubleshooting

### Issue: Blank screen on page load
**Solution**: Check browser console for errors, ensure CanvasKit is loaded correctly

### Issue: Slow performance
**Solution**: 
- Switch to CanvasKit renderer
- Check network tab for missing assets
- Profile using Chrome DevTools

### Issue: API calls failing
**Solution**:
- Ensure CORS headers are set on backend
- Check API URL in `app_config.dart`
- Verify backend is running

### Issue: Hot reload not working
**Solution**: Use HTML renderer during development, rebuild if needed

## Related Documentation

- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Flutter Web Performance](https://docs.flutter.dev/development/performance)
- [CanvasKit Documentation](https://skia.org/docs/user/modules/canvaskit/)
