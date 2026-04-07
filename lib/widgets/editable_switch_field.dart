import 'package:flutter/material.dart';

class EditableSwitchField extends StatefulWidget {
  final String labelText;
  final Widget? leading;
  final bool isEditable;
  final bool initialValue;
  final bool isRequired;
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
    this.isRequired = false,
  });

  @override
  State<EditableSwitchField> createState() => _EditableSwitchFieldState();
}

class _EditableSwitchFieldState extends State<EditableSwitchField> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant EditableSwitchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync internal state if the parent updates the initialValue
    if (oldWidget.initialValue != widget.initialValue) {
      setState(() {
        _value = widget.initialValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Define the error style using the existing theme rather than inline properties
    final errorTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
    );

    return FormField<bool>(
      initialValue: _value,
      validator: (value) {
        if (widget.isRequired && (value == null || value == false)) {
          return 'This field is required.';
        }
        return widget.validator?.call(value ?? false);
      },
      builder: (field) {
        final errorText = field.errorText;

        if (widget.isEditable) {
          return SwitchListTile(
            title: Text(widget.labelText),
            secondary: widget.leading,
            value: _value,
            activeThumbColor: theme.colorScheme.primary,
            onChanged: (newValue) {
              setState(() {
                _value = newValue;
              });
              field.didChange(newValue);
              widget.onChanged?.call(newValue);
            },
            subtitle: errorText != null
                ? Text(errorText, style: errorTextStyle)
                : null,
          );
        } else {
          return ListTile(
            title: Text(widget.labelText),
            leading: widget.leading,
            subtitle: errorText != null
                ? Text(errorText, style: errorTextStyle)
                : null,
            trailing: Icon(
              _value ? Icons.check : Icons.close,
              size: 24.0,
              color: _value
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          );
        }
      },
    );
  }
}