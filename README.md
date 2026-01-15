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
  <a href="https://github.com/Aadhityan-A/hpcc-connect/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/Aadhityan-A/hpcc-connect?style=flat-square" alt="License">
  </a>
</p>

---

## 📥 Download

| Platform | Download | Notes |
|----------|----------|-------|
| **Windows** | [Installer (.exe)](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.4.0/hpcc-connect-windows-x64-setup.exe) | Recommended |
| **Linux** | [AppImage](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.4.0/hpcc-connect-1.4.0-x86_64.AppImage) | Works on any distro |
| **Linux** | [.deb package](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.4.0/hpcc-connect_1.4.0_amd64.deb) | Ubuntu/Debian |
| **macOS** | [DMG](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.4.0/hpcc-connect-macos.dmg) | macOS 10.14+ |
| **Android** | [APK (arm64-v8a)](https://github.com/Aadhityan-A/hpcc-connect/releases/download/v1.4.0/hpcc-connect-app-arm64-v8a-release.apk) | Android 5.0+ |

➡️ **[View All Releases](https://github.com/Aadhityan-A/hpcc-connect/releases)**

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

## License

This project is licensed under the CeCILL v2.1 License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please fork the repository and open a Pull Request.

## Acknowledgments

- [dartssh2](https://pub.dev/packages/dartssh2) - SSH2 client library
- [xterm](https://pub.dev/packages/xterm) - Terminal emulator widget
- [Flutter](https://flutter.dev/) - UI framework
