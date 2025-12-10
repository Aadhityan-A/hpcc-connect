/// Represents a file or directory entry in file browser
class FileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modifiedTime;
  final String? permissions;
  final bool isLocal;

  FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modifiedTime,
    this.permissions,
    required this.isLocal,
  });

  String get displaySize {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get extension {
    if (isDirectory) return '';
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return '';
    return name.substring(dotIndex + 1).toLowerCase();
  }

  FileEntry copyWith({
    String? name,
    String? path,
    bool? isDirectory,
    int? size,
    DateTime? modifiedTime,
    String? permissions,
    bool? isLocal,
  }) {
    return FileEntry(
      name: name ?? this.name,
      path: path ?? this.path,
      isDirectory: isDirectory ?? this.isDirectory,
      size: size ?? this.size,
      modifiedTime: modifiedTime ?? this.modifiedTime,
      permissions: permissions ?? this.permissions,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  @override
  String toString() => 'FileEntry(name: $name, isDir: $isDirectory, isLocal: $isLocal)';
}

/// Transfer operation for file copy
enum TransferOperation {
  upload,
  download,
}

/// Represents a file transfer task
class FileTransfer {
  final String id;
  final String sourcePath;
  final String destinationPath;
  final TransferOperation operation;
  final int totalBytes;
  int transferredBytes;
  TransferStatus status;
  String? error;

  FileTransfer({
    required this.id,
    required this.sourcePath,
    required this.destinationPath,
    required this.operation,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
    this.error,
  });

  double get progress {
    if (totalBytes == 0) return 0;
    return transferredBytes / totalBytes;
  }

  String get progressText {
    return '${(progress * 100).toStringAsFixed(1)}%';
  }
}

enum TransferStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
}
