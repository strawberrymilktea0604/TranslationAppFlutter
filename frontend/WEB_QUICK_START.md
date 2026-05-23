# Quick Start Guide - Flutter Web Admin Dashboard

## Setup

### Prerequisites
- Flutter SDK 3.10.7+ 
- Chrome/Chromium browser
- Backend API running on `http://localhost:8000`

## Quick Start

### 1. Development (Faster Builds - HTML Renderer)
```bash
cd frontend
flutter run -d web --target=lib/main_web.dart --web-renderer html
```

Browser opens at: `http://localhost:55391` (port may vary)

### 2. Development (Better Performance - CanvasKit)
```bash
cd frontend
flutter run -d web --target=lib/main_web.dart --web-renderer canvaskit
```

### 3. Production Build
```bash
cd frontend
flutter build web --target=lib/main_web.dart --web-renderer canvaskit --release
```

Output: `frontend/build/web/`

## Project Structure

```
Admin Dashboard Layout:
├── Sidebar (Collapsible on desktop, drawer on mobile)
│   ├── Logo
│   ├── Navigation Items:
│   │   ├── Dashboard
│   │   ├── Người dùng (Users)
│   │   ├── Dịch vụ (Translations)
│   │   ├── Thống kê (Analytics)
│   │   └── Cài đặt (Settings)
│   └── Status indicator
├── Topbar
│   ├── Title
│   ├── Search
│   ├── Notifications
│   └── User Menu (Profile, Settings, Logout)
└── Main Content Area
    └── Page-specific content
```

## Pages

### Dashboard (`/admin/dashboard`)
- System overview with statistics
- Recent activity feed
- Key metrics cards

### Users (`/admin/users`)
- User management table
- Search and filter
- Add/Edit/Delete users
- Role and status management

### Translations (`/admin/translations`)
- Translation history
- Filter by type (Text, Image, Voice)
- View and delete translations
- Usage statistics

### Analytics (`/admin/analytics`)
- Usage trends
- Performance metrics
- Language popularity
- Top users/translations

## Features Implemented

✅ Sidebar navigation (collapsible)
✅ Responsive Topbar
✅ Dashboard overview
✅ User management table
✅ Translation management table
✅ Analytics dashboard
✅ Mobile-responsive design
✅ Light/Dark theme support (configurable)
✅ Multi-language support (EN, VI)

## TODO Items

- [ ] Connect to real API endpoints
- [ ] Implement user authentication check
- [ ] Add admin role validation
- [ ] Implement search/filter functionality
- [ ] Add chart libraries (fl_chart, charts)
- [ ] Implement dialogs for add/edit operations
- [ ] Add export functionality
- [ ] Implement real-time notifications
- [ ] Add settings page
- [ ] Setup service worker for offline capability

## Environment Configuration

### Development
- API URL: `http://localhost:8000/api/v1`
- Renderer: HTML (faster builds)
- Debug mode: Enabled

### Production
- API URL: `https://api.translation-app.com/api/v1`
- Renderer: CanvasKit (better performance)
- Debug mode: Disabled

To change in `lib/main_web.dart`:
```dart
config = const AppConfig(
  appName: 'Translation Admin',
  apiUrl: 'http://localhost:8000/api/v1',  // Change this
);
```

## Router Structure

```
Admin Routes (/admin/*)
├── /admin/dashboard        → AdminDashboardPage
├── /admin/users           → AdminUsersPage
├── /admin/translations    → AdminTranslationsPage
├── /admin/analytics       → AdminAnalyticsPage
└── /admin/settings        → AdminSettingsPage (TODO)

Redirect Logic:
- Unauthenticated → /login
- No admin role → /login (TODO)
- Otherwise → Allowed
```

## Web Renderer Comparison

| Feature | HTML | CanvasKit |
|---------|------|-----------|
| Bundle Size | Smaller | ~8-10MB |
| Compilation | Faster | Slower |
| Runtime Performance | Good | Better |
| Consistency | Variable | Excellent |
| Browser Support | Broader | Chrome 90+ |

**Recommendation**: 
- Development: HTML (faster hot reload)
- Production: CanvasKit (better UX)

## Debugging

### Check Console
```javascript
// Open DevTools (F12)
// Console shows Flutter errors and logs
```

### Performance Profiling
```javascript
// In Chrome DevTools
// Performance tab → Record → Interact → Stop
```

### Flutter Logs
```bash
flutter logs --web
```

## Common Issues

### Page not loading
- Check browser console for errors
- Verify backend API is running
- Check API URL in `app_config.dart`

### Sidebar not visible
- Page may still be loading
- Check Flutter logs for errors
- Try hard refresh (Ctrl+Shift+R)

### Performance is slow
- Try CanvasKit renderer
- Close other browser tabs
- Clear browser cache

## Next Steps

1. Connect API endpoints
2. Implement real data loading
3. Add chart libraries for analytics
4. Setup authentication
5. Deploy to production server

## Documentation Links

- [WEB_CONFIGURATION.md](WEB_CONFIGURATION.md) - Detailed configuration
- [Flutter Web Docs](https://docs.flutter.dev/deployment/web)
- [Material Design 3](https://m3.material.io/)

## Support

For issues or questions:
1. Check Flutter logs: `flutter logs --web`
2. Review browser console errors
3. Check API connectivity
4. See WEB_CONFIGURATION.md for troubleshooting
