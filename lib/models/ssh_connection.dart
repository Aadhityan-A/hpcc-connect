import 'package:hive/hive.dart';

part 'ssh_connection.g.dart';

@HiveType(typeId: 0)
class SSHConnection extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String host;

  @HiveField(3)
  int port;

  @HiveField(4)
  String username;

  @HiveField(5)
  String? password;

  @HiveField(6)
  String? privateKey;

  @HiveField(7)
  String? passphrase;

  @HiveField(8)
  AuthType authType;

  @HiveField(9)
  String? remoteWorkingDirectory;

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime? lastConnected;

  SSHConnection({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.passphrase,
    this.authType = AuthType.password,
    this.remoteWorkingDirectory,
    DateTime? createdAt,
    this.lastConnected,
  }) : createdAt = createdAt ?? DateTime.now();

  SSHConnection copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    String? passphrase,
    AuthType? authType,
    String? remoteWorkingDirectory,
    DateTime? createdAt,
    DateTime? lastConnected,
  }) {
    return SSHConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      authType: authType ?? this.authType,
      remoteWorkingDirectory: remoteWorkingDirectory ?? this.remoteWorkingDirectory,
      createdAt: createdAt ?? this.createdAt,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKey': privateKey,
      'passphrase': passphrase,
      'authType': authType.index,
      'remoteWorkingDirectory': remoteWorkingDirectory,
      'createdAt': createdAt.toIso8601String(),
      'lastConnected': lastConnected?.toIso8601String(),
    };
  }

  factory SSHConnection.fromJson(Map<String, dynamic> json) {
    return SSHConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      password: json['password'] as String?,
      privateKey: json['privateKey'] as String?,
      passphrase: json['passphrase'] as String?,
      authType: AuthType.values[json['authType'] as int? ?? 0],
      remoteWorkingDirectory: json['remoteWorkingDirectory'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastConnected: json['lastConnected'] != null
          ? DateTime.parse(json['lastConnected'] as String)
          : null,
    );
  }

  @override
  String toString() => 'SSHConnection(name: $name, host: $host, port: $port, user: $username)';
}

@HiveType(typeId: 1)
enum AuthType {
  @HiveField(0)
  password,

  @HiveField(1)
  privateKey,
}

extension AuthTypeExtension on AuthType {
  String get displayName {
    switch (this) {
      case AuthType.password:
        return 'Password';
      case AuthType.privateKey:
        return 'Private Key';
    }
  }
}
