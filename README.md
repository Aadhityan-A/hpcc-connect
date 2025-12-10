# HPCC Connect

<p align="center">
  <img src="assets/icons/hpcc-connect.svg" width="128" height="128" alt="HPCC Connect Logo">
</p>

<p align="center">
  <strong>Cross-platform SSH Terminal Client with File Browser</strong>
</p>

<p align="center">
    <a href="https://github.com/Aadhityan-A/hpcc-connect/releases">
    <img src="https://img.shields.io/github/v/release/Aadhityan-A/hpcc-connect?style=flat-square" alt="Release">
  </a>
  <a href="https://github.com/Aadhityan-A/hpcc-connect/actions">
    <img src="https://img.shields.io/github/actions/workflow/status/Aadhityan-A/hpcc-connect/build.yml?style=flat-square" alt="Build Status">
  </a>
  <a href="https://github.com/Aadhityan-A/hpcc-connect/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/Aadhityan-A/hpcc-connect?style=flat-square" alt="License">
  </a>
</p>

---

## 📥 Quick Download

| Platform | Download | Notes |
|----------|----------|-------|
| **Windows** | [Installer (.exe)](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.0.0/hpcc-connect-windows-x64-setup.exe) | Recommended |
| **Linux** | [AppImage](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.0.0/hpcc-connect-1.0.0-x86_64.AppImage) | Works on any distro |
| **Linux** | [.deb package](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.0.0/hpcc-connect_1.0.0_amd64.deb) | Ubuntu/Debian |
| **macOS** | [DMG](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.0.0/hpcc-connect-macos.dmg) | macOS 10.14+ |
| **Android** | [APK (arm64-v8a)](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.0.0/hpcc-connect-app-arm64-v8a-release.apk) | Android 5.0+ |

➡️ **[View All v1.0.0 Assets](https://github.com/Aadhityan-A/hpcc-connect/releases/tag/v1.0.0)**

---

## ✨ Features

- 🖥️ **SSH Terminal** - Full-featured terminal with PTY support
- 📁 **Dual-pane File Browser** - Browse local and remote files side by side
- 🔄 **Drag & Drop Transfers** - Easy file transfers between local and remote
- 💾 **Connection Manager** - Save and manage multiple SSH connections
- 🔐 **Secure Authentication** - Password and SSH key support
- 🌙 **Dark/Light Theme** - Automatic theme based on system preference
- 📱 **Cross-platform** - Android, Windows, Linux, macOS

---

## 🚀 Quick Start

1. **Download and install** for your platform (see above)
2. **Launch the app**
3. **Click "+"** to add a new SSH connection
4. **Enter server details** (host, username, password)
5. **Connect** and start using the terminal and file browser!

---

## 🛠️ Troubleshooting

### Linux: "symbol lookup error" or library issues
Use the **AppImage** version which bundles all dependencies:
```bash
chmod +x hpcc-connect-*-x86_64.AppImage
./hpcc-connect-*-x86_64.AppImage
```

### Database errors on startup
The app auto-recovers from corrupted data. If issues persist, delete the data folder:
```bash
# Linux
rm -rf ~/.local/share/com.example.hpcc_connect/

# Windows
rmdir /s %LOCALAPPDATA%\com.example.hpcc_connect
```

### macOS: "App is damaged" error
```bash
xattr -cr /Applications/hpcc_connect.app
```

---

## Building for Each Platform

### Android

#### Prerequisites
1. Install Android Studio
2. Install Android SDK (API 21+)
3. Set up Android SDK path in `local.properties`

#### Build APK
```bash
# Debug APK
flutter build apk --debug

# Release APK (all architectures)
flutter build apk --release

# Split APKs by architecture (smaller size)
flutter build apk --release --split-per-abi
```

#### Build App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

#### Output locations:
- APK: `build/app/outputs/flutter-apk/app-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

#### Install on device
```bash
# Via ADB
adb install build/app/outputs/flutter-apk/app-release.apk

# Or directly with Flutter
flutter install
```

---

### Windows

#### Prerequisites
1. Install Visual Studio 2022 with:
   - "Desktop development with C++" workload
   - Windows 10 SDK
2. Enable Windows desktop support:
```bash
flutter config --enable-windows-desktop
```

#### Build
```bash
# Debug
flutter build windows --debug

# Release
flutter build windows --release
```

#### Output location:
- `build/windows/x64/runner/Release/hpcc_connect.exe`

#### Creating an Installer (optional)
Using [Inno Setup](https://jrsoftware.org/isinfo.php):

1. Install Inno Setup
2. Create a script `installer.iss`:
```iss
[Setup]
AppName=HPCC Connect
AppVersion=1.0.0
DefaultDirName={autopf}\HPCC Connect
DefaultGroupName=HPCC Connect
OutputDir=build\installer
OutputBaseFilename=HPCCConnect-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\HPCC Connect"; Filename: "{app}\hpcc_connect.exe"
Name: "{commondesktop}\HPCC Connect"; Filename: "{app}\hpcc_connect.exe"
```
3. Compile with Inno Setup Compiler

---

### Linux

#### Prerequisites
1. Install required packages:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev

# Fedora
sudo dnf install -y clang cmake ninja-build gtk3-devel

# Arch Linux
sudo pacman -S clang cmake ninja gtk3
```

2. Enable Linux desktop support:
```bash
flutter config --enable-linux-desktop
```

#### Build
```bash
# Debug
flutter build linux --debug

# Release
flutter build linux --release
```

#### Output location:
- `build/linux/x64/release/bundle/`

#### Running
```bash
./build/linux/x64/release/bundle/hpcc_connect
```

#### Creating a .deb package (Ubuntu/Debian)
```bash
# Install flutter_distributor
dart pub global activate flutter_distributor

# Create distribution config
mkdir -p dist

# Build .deb
flutter_distributor package --platform linux --targets deb
```

#### Creating AppImage
1. Install `appimagetool`:
```bash
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
```

2. Create AppDir structure:
```bash
mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/share/applications
mkdir -p AppDir/usr/share/icons/hicolor/256x256/apps

cp -r build/linux/x64/release/bundle/* AppDir/usr/bin/
```

3. Create desktop entry and build AppImage

---

### macOS

#### Prerequisites
1. Install Xcode from App Store
2. Install Xcode command line tools:
```bash
xcode-select --install
```
3. Accept Xcode license:
```bash
sudo xcodebuild -license accept
```
4. Enable macOS desktop support:
```bash
flutter config --enable-macos-desktop
```

#### Build
```bash
# Debug
flutter build macos --debug

# Release
flutter build macos --release
```

#### Output location:
- `build/macos/Build/Products/Release/HPCC Connect.app`

#### Creating a DMG installer
```bash
# Install create-dmg
brew install create-dmg

# Create DMG
create-dmg \
  --volname "HPCC Connect" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 425 178 \
  "HPCC-Connect-Installer.dmg" \
  "build/macos/Build/Products/Release/HPCC Connect.app"
```


## Configuration

### Adding SSH Connections

1. Click the **+** button in the sidebar
2. Fill in connection details:
   - **Name**: Display name for the connection
   - **Host**: HPCC hostname or IP address
   - **Port**: SSH port (default: 22)
   - **Username**: Your HPCC username
   - **Authentication**: Password or Private Key
3. Click **Test** to verify connection
4. Click **Save**

### Using Private Key Authentication

1. Select "Private Key" as authentication type
2. Either paste your private key content or click the folder icon to select a file
3. Enter passphrase if your key is encrypted
4. Save the connection

---

## Usage

### Connecting to HPCC
1. Select a saved connection from the sidebar
2. Double-click or press Enter to connect
3. The terminal will initialize and show the shell prompt
4. The file browser will display your remote home directory

### File Transfer
- **Upload**: Select files in local pane → Click upload button or drag to remote pane
- **Download**: Select files in remote pane → Click download button or drag to local pane
- **Monitor**: Check the status bar at bottom for transfer progress

### Terminal
- Type commands as you would in a normal SSH terminal
- Terminal supports xterm-256color
- Use Ctrl+C, Ctrl+Z, and other standard shortcuts

---

## Troubleshooting

### Connection Issues
- Verify hostname and port are correct
- Check if your network allows SSH connections
- Ensure your credentials are valid
- Try connecting via regular SSH client first

### Android Storage Access
- Grant storage permissions when prompted
- For Android 11+, go to Settings → Apps → HPCC Connect → Permissions → Files

### Linux Build Errors
```bash
# If GTK errors occur
sudo apt-get install libgtk-3-dev pkg-config

# If CMake errors occur
sudo apt-get install cmake ninja-build
```

### Windows Build Errors
- Ensure Visual Studio 2022 is installed with C++ workload
- Run `flutter doctor -v` to verify setup

---

## Development

### Project Structure
```
lib/
├── main.dart              # App entry point
├── models/                # Data models
│   ├── file_entry.dart    # File/directory representation
│   └── ssh_connection.dart # SSH connection model
├── providers/             # State management
│   ├── connection_provider.dart
│   ├── file_browser_provider.dart
│   └── terminal_provider.dart
├── screens/               # App screens
│   └── home_screen.dart
├── services/              # Business logic
│   ├── local_file_service.dart
│   └── ssh_service.dart
├── theme/                 # App theming
│   └── app_theme.dart
└── widgets/               # UI components
    ├── connection_dialog.dart
    ├── connection_sidebar.dart
    ├── file_browser_panel.dart
    ├── file_list_view.dart
    ├── terminal_panel.dart
    └── transfer_status_bar.dart
```

### Running in Development
```bash
# Run on connected device/emulator
flutter run

# Run with specific device
flutter run -d windows
flutter run -d linux
flutter run -d macos

# Hot reload during development
# Press 'r' in terminal or save files in IDE
```

### Running Tests
```bash
flutter test
```

---

## License

This project is licensed under the CeCILL v2.1 License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Acknowledgments

- [dartssh2](https://pub.dev/packages/dartssh2) - SSH2 client library
- [xterm](https://pub.dev/packages/xterm) - Terminal emulator widget
- [Flutter](https://flutter.dev/) - UI framework
