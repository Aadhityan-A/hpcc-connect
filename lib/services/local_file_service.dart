import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/file_entry.dart';

/// Service for local file system operations
class LocalFileService {
  /// Get home directory based on platform
  String getHomeDirectory() {
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ?? 'C:\\';
    } else if (Platform.isAndroid) {
      return '/storage/emulated/0';
    } else {
      return Platform.environment['HOME'] ?? '/';
    }
  }

  /// Get list of root directories
  List<String> getRootDirectories() {
    if (Platform.isWindows) {
      // Get Windows drives
      final drives = <String>[];
      for (int i = 65; i <= 90; i++) {
        final drive = '${String.fromCharCode(i)}:\\';
        if (Directory(drive).existsSync()) {
          drives.add(drive);
        }
      }
      return drives.isEmpty ? ['C:\\'] : drives;
    } else if (Platform.isAndroid) {
      return ['/storage/emulated/0', '/'];
    } else {
      return ['/'];
    }
  }

  /// List directory contents
  Future<List<FileEntry>> listDirectory(String path) async {
    final directory = Directory(path);
    
    if (!await directory.exists()) {
      throw FileSystemException('Directory does not exist', path);
    }

    final entries = <FileEntry>[];
    
    try {
      await for (final entity in directory.list(followLinks: false)) {
        try {
          final stat = await entity.stat();
          final name = p.basename(entity.path);
          
          // Skip hidden files on Unix-like systems (optional, can be toggled)
          // if (!Platform.isWindows && name.startsWith('.')) continue;
          
          entries.add(FileEntry(
            name: name,
            path: entity.path,
            isDirectory: entity is Directory,
            size: stat.size,
            modifiedTime: stat.modified,
            permissions: _formatPermissions(stat.mode),
            isLocal: true,
          ));
        } catch (_) {
          // Skip files we can't access
        }
      }
    } catch (e) {
      throw FileSystemException('Cannot read directory: $e', path);
    }

    // Sort: directories first, then by name
    entries.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }

  /// Create directory
  Future<void> createDirectory(String path) async {
    await Directory(path).create(recursive: true);
  }

  /// Delete file or directory
  Future<void> delete(String path, {bool isDirectory = false}) async {
    if (isDirectory) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  /// Rename file or directory
  Future<void> rename(String oldPath, String newPath) async {
    final entity = FileSystemEntity.typeSync(oldPath) == FileSystemEntityType.directory
        ? Directory(oldPath)
        : File(oldPath);
    await entity.rename(newPath);
  }

  /// Copy file
  Future<void> copyFile(String source, String destination) async {
    await File(source).copy(destination);
  }

  /// Move file or directory
  Future<void> move(String source, String destination) async {
    final sourceType = FileSystemEntity.typeSync(source);
    if (sourceType == FileSystemEntityType.directory) {
      await _moveDirectory(source, destination);
    } else {
      await File(source).rename(destination);
    }
  }

  Future<void> _moveDirectory(String source, String destination) async {
    final sourceDir = Directory(source);
    final destDir = Directory(destination);
    
    await destDir.create(recursive: true);
    
    await for (final entity in sourceDir.list(recursive: false)) {
      final newPath = p.join(destination, p.basename(entity.path));
      if (entity is Directory) {
        await _moveDirectory(entity.path, newPath);
      } else {
        await File(entity.path).rename(newPath);
      }
    }
    
    await sourceDir.delete();
  }

  /// Check if path exists
  Future<bool> exists(String path) async {
    return await FileSystemEntity.type(path) != FileSystemEntityType.notFound;
  }

  /// Get file size
  Future<int> getFileSize(String path) async {
    return await File(path).length();
  }

  /// Get parent directory
  String getParentDirectory(String path) {
    return p.dirname(path);
  }

  /// Join paths
  String joinPaths(String base, String child) {
    if (Platform.isWindows) {
      return p.windows.join(base, child);
    }
    return p.posix.join(base, child);
  }

  /// Read file content as string
  Future<String> readFileContent(String path) async {
    final file = File(path);
    return await file.readAsString();
  }

  /// Write content to file
  Future<void> writeFileContent(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }

  /// Get temp directory path
  Future<String> getTempDirectory() async {
    return Directory.systemTemp.path;
  }

  /// Create a unique temp file path for a given filename
  Future<String> createTempFilePath(String fileName) async {
    final tempDir = await getTempDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return joinPaths(tempDir, 'hpcc_connect_${timestamp}_$fileName');
  }

  String _formatPermissions(int mode) {
    if (Platform.isWindows) {
      return '----------';
    }

    final perms = StringBuffer();
    
    // File type
    if (FileSystemEntity.isDirectorySync(mode.toString())) {
      perms.write('d');
    } else {
      perms.write('-');
    }
    
    // Owner permissions
    perms.write((mode & 0x100) != 0 ? 'r' : '-');
    perms.write((mode & 0x80) != 0 ? 'w' : '-');
    perms.write((mode & 0x40) != 0 ? 'x' : '-');
    
    // Group permissions
    perms.write((mode & 0x20) != 0 ? 'r' : '-');
    perms.write((mode & 0x10) != 0 ? 'w' : '-');
    perms.write((mode & 0x8) != 0 ? 'x' : '-');
    
    // Other permissions
    perms.write((mode & 0x4) != 0 ? 'r' : '-');
    perms.write((mode & 0x2) != 0 ? 'w' : '-');
    perms.write((mode & 0x1) != 0 ? 'x' : '-');
    
    return perms.toString();
  }
}
