import 'package:hive/hive.dart';

part 'command_snippet.g.dart';

@HiveType(typeId: 2)
class CommandSnippet extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String command;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? updatedAt;

  CommandSnippet({
    required this.id,
    required this.name,
    required this.command,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  CommandSnippet copyWith({
    String? id,
    String? name,
    String? command,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CommandSnippet(
      id: id ?? this.id,
      name: name ?? this.name,
      command: command ?? this.command,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'command': command,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory CommandSnippet.fromJson(Map<String, dynamic> json) {
    return CommandSnippet(
      id: json['id'] as String,
      name: json['name'] as String,
      command: json['command'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'CommandSnippet(id: $id, name: $name, command: $command)';
  }
}
