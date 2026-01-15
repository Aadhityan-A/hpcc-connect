// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ssh_connection.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SSHConnectionAdapter extends TypeAdapter<SSHConnection> {
  @override
  final int typeId = 0;

  @override
  SSHConnection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SSHConnection(
      id: fields[0] as String,
      name: fields[1] as String,
      host: fields[2] as String,
      port: fields[3] as int,
      username: fields[4] as String,
      password: fields[5] as String?,
      privateKey: fields[6] as String?,
      passphrase: fields[7] as String?,
      authType: fields[8] as AuthType,
      remoteWorkingDirectory: fields[9] as String?,
      createdAt: fields[10] as DateTime?,
      lastConnected: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SSHConnection obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.host)
      ..writeByte(3)
      ..write(obj.port)
      ..writeByte(4)
      ..write(obj.username)
      ..writeByte(5)
      ..write(obj.password)
      ..writeByte(6)
      ..write(obj.privateKey)
      ..writeByte(7)
      ..write(obj.passphrase)
      ..writeByte(8)
      ..write(obj.authType)
      ..writeByte(9)
      ..write(obj.remoteWorkingDirectory)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.lastConnected);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSHConnectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AuthTypeAdapter extends TypeAdapter<AuthType> {
  @override
  final int typeId = 1;

  @override
  AuthType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AuthType.password;
      case 1:
        return AuthType.privateKey;
      default:
        return AuthType.password;
    }
  }

  @override
  void write(BinaryWriter writer, AuthType obj) {
    switch (obj) {
      case AuthType.password:
        writer.writeByte(0);
        break;
      case AuthType.privateKey:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
