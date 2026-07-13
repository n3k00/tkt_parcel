import 'package:flutter/material.dart';

class GateTextPromptDialog extends StatefulWidget {
  const GateTextPromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
  });

  final String title;
  final String label;
  final String confirmLabel;

  @override
  State<GateTextPromptDialog> createState() => _GateTextPromptDialogState();
}

class _GateTextPromptDialogState extends State<GateTextPromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            Navigator.pop(context, value.isEmpty ? null : value);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
