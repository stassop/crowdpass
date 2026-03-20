import 'package:flutter/material.dart';

class EditableSwitchField extends StatefulWidget {
  final String labelText;
  final Widget? leading;
  final bool isEditable;
  final bool initialValue;
  final ValueChanged<bool>? onChanged;
  final String? Function(bool)? validator;

  const EditableSwitchField({
    super.key,
    required this.isEditable,
    required this.labelText,
    required this.onChanged,
    this.initialValue = false,
    this.leading,
    this.validator,
  });

  @override
  State<EditableSwitchField> createState() => _EditableSwitchFieldState();
}

class _EditableSwitchFieldState extends State<EditableSwitchField> {
  bool _value = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _error = widget.validator?.call(_value);
  }

  @override
  void didUpdateWidget(covariant EditableSwitchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setState(() {
        _value = widget.initialValue;
        _error = widget.validator?.call(_value);
      });
    }
  }

  void _onChanged(bool newValue) {
    setState(() {
      _value = newValue;
      _error = widget.validator?.call(_value);
    });
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isEditable) {
      return SwitchListTile(
        title: Text(widget.labelText),
        secondary: widget.leading,
        value: _value,
        onChanged: _onChanged,
        activeThumbColor: theme.colorScheme.primary,
        subtitle: _error != null ? Text(_error!, style: TextStyle(color: theme.colorScheme.error)) : null,
      );
    } else {
      return ListTile(
        title: Text(widget.labelText),
        leading: widget.leading,
        subtitle: _error != null ? Text(_error!, style: TextStyle(color: theme.colorScheme.error)) : null,
        trailing: Icon(
          _value ? Icons.check : Icons.close,
          size: 24.0,
          color: _value
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
      );
    }
  }
}
