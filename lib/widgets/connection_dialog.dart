import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/ssh_connection.dart';
import '../providers/connection_provider.dart';

class ConnectionDialog extends StatefulWidget {
  final SSHConnection connection;
  final bool isNew;

  const ConnectionDialog({
    super.key,
    required this.connection,
    required this.isNew,
  });

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _privateKeyController;
  late TextEditingController _passphraseController;
  late TextEditingController _remotePathController;
  
  late AuthType _authType;
  bool _obscurePassword = true;
  bool _isTesting = false;
  bool? _testResult;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.connection.name);
    _hostController = TextEditingController(text: widget.connection.host);
    _portController = TextEditingController(text: widget.connection.port.toString());
    _usernameController = TextEditingController(text: widget.connection.username);
    _passwordController = TextEditingController(text: widget.connection.password ?? '');
    _privateKeyController = TextEditingController(text: widget.connection.privateKey ?? '');
    _passphraseController = TextEditingController(text: widget.connection.passphrase ?? '');
    _remotePathController = TextEditingController(text: widget.connection.remoteWorkingDirectory ?? '');
    _authType = widget.connection.authType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    _remotePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Add Connection' : 'Edit Connection'),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Connection Name',
                    hintText: 'e.g., HPCC Production',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Host',
                          hintText: 'e.g., hpcc.example.com',
                          prefixIcon: Icon(Icons.computer),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter hostname';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final port = int.tryParse(value);
                          if (port == null || port < 1 || port > 65535) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AuthType>(
                  // TODO: Drop the ignore and switch to `initialValue` once CI moves past Flutter 3.32.
                  // ignore: deprecated_member_use
                  value: _authType,
                  decoration: const InputDecoration(
                    labelText: 'Authentication Type',
                    prefixIcon: Icon(Icons.security),
                  ),
                  items: AuthType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _authType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_authType == AuthType.password) ...[
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (_authType == AuthType.password && (value == null || value.isEmpty)) {
                        return 'Please enter password';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _privateKeyController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Private Key',
                            hintText: 'Paste your private key here or select file',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            if (_authType == AuthType.privateKey && (value == null || value.isEmpty)) {
                              return 'Please provide private key';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.folder_open),
                        onPressed: _pickPrivateKeyFile,
                        tooltip: 'Select private key file',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passphraseController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Passphrase (optional)',
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _remotePathController,
                  decoration: const InputDecoration(
                    labelText: 'Remote Working Directory (optional)',
                    hintText: 'e.g., /home/user/projects',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                if (_testResult != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: _testResult!
                          ? Colors.green.withAlpha(26)
                          : Colors.red.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _testResult! ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testResult! ? Icons.check_circle : Icons.error,
                          color: _testResult! ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _testResult! 
                              ? 'Connection successful!' 
                              : 'Connection failed',
                          style: TextStyle(
                            color: _testResult! ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _isTesting ? null : _testConnection,
          child: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Test'),
        ),
        ElevatedButton(
          onPressed: _saveConnection,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _pickPrivateKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        // Read file content
        final content = await _readFileContent(file.path!);
        if (content != null) {
          _privateKeyController.text = content;
        }
      }
    }
  }

  Future<String?> _readFileContent(String path) async {
    try {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (file?.files.first.bytes != null) {
        return String.fromCharCodes(file!.files.first.bytes!);
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final connection = _buildConnection();
    final provider = context.read<ConnectionProvider>();
    final success = await provider.testConnection(connection);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = success;
      });
    }
  }

  void _saveConnection() {
    if (!_formKey.currentState!.validate()) return;

    final connection = _buildConnection();
    final provider = context.read<ConnectionProvider>();

    if (widget.isNew) {
      provider.addConnection(connection);
    } else {
      provider.updateConnection(connection);
    }

    Navigator.of(context).pop();
  }

  SSHConnection _buildConnection() {
    return SSHConnection(
      id: widget.connection.id,
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.parse(_portController.text.trim()),
      username: _usernameController.text.trim(),
      password: _authType == AuthType.password ? _passwordController.text : null,
      privateKey: _authType == AuthType.privateKey ? _privateKeyController.text : null,
      passphrase: _authType == AuthType.privateKey && _passphraseController.text.isNotEmpty
          ? _passphraseController.text
          : null,
      authType: _authType,
      remoteWorkingDirectory: _remotePathController.text.isNotEmpty
          ? _remotePathController.text.trim()
          : null,
      createdAt: widget.connection.createdAt,
      lastConnected: widget.connection.lastConnected,
    );
  }
}
