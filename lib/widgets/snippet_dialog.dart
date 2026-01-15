import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/command_snippet.dart';
import '../providers/snippet_provider.dart';

/// Dialog for adding or editing command snippets
class SnippetDialog extends StatefulWidget {
  final CommandSnippet snippet;
  final bool isNew;

  const SnippetDialog({
    super.key,
    required this.snippet,
    required this.isNew,
  });

  @override
  State<SnippetDialog> createState() => _SnippetDialogState();
}

class _SnippetDialogState extends State<SnippetDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _commandController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.snippet.name);
    _commandController = TextEditingController(text: widget.snippet.command);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<SnippetProvider>();
    final updatedSnippet = widget.snippet.copyWith(
      name: _nameController.text.trim(),
      command: _commandController.text.trim(),
      updatedAt: widget.isNew ? null : DateTime.now(),
    );

    if (widget.isNew) {
      await provider.addSnippet(updatedSnippet);
    } else {
      await provider.updateSnippet(updatedSnippet);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isNew ? Icons.add_circle_outline : Icons.edit_outlined,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(widget.isNew ? 'Add Snippet' : 'Edit Snippet'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter a name for this snippet',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Command field
              TextFormField(
                controller: _commandController,
                decoration: InputDecoration(
                  labelText: 'Command',
                  hintText: 'Enter the command to execute',
                  prefixIcon: const Icon(Icons.terminal),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a command';
                  }
                  return null;
                },
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 12),

              // Helper text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withAlpha(30)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.blue.withAlpha(60)
                        : Colors.blue.shade100,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Click on the snippet to paste it into the active terminal.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.blue.shade300
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(widget.isNew ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
