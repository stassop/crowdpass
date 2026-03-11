import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String? title;
  final String? message;
  final List<Widget>? actions;

  const ErrorDialog({
    super.key,
    this.title,
    this.message,
    this.actions,
  });

  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
    List<Widget>? actions,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ErrorDialog(
        title: title,
        message: message,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title ?? 'Error'),
      content: Text(message ?? 'An unknown error occurred.'),
      actions: [
        if (actions != null) ...actions!,
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
