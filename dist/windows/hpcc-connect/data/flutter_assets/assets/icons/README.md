# App Icons

This directory contains application icons.

## Generated Files
- `app_icon.svg` - Vector icon source

## To generate platform-specific icons:

### Using flutter_launcher_icons package

1. Add to pubspec.yaml dev_dependencies:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1
```

2. Add configuration to pubspec.yaml:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  windows:
    generate: true
  macos:
    generate: true
  image_path: "assets/icons/app_icon.png"
```

3. Create a 1024x1024 PNG from the SVG

4. Run:
```bash
flutter pub get
dart run flutter_launcher_icons
```

## Manual Icon Generation

For a quick solution, you can use online tools to convert the SVG to required formats:
- Android: 48x48 to 192x192 (mdpi to xxxhdpi)
- iOS: 20x20 to 1024x1024 (various scales)
- Windows: 256x256 .ico
- macOS: 16x16 to 1024x1024 .icns
