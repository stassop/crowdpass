import 'package:flutter/material.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';

class EditablePasswordField extends StatefulWidget {
  final String? initialValue;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final TextStyle? textStyle;
  final String? Function(String?)? validator;
  final bool isRequired;

  const EditablePasswordField({
    super.key,
    this.initialValue,
    this.decoration,
    this.onChanged,
    this.textStyle,
    this.validator,
    this.isRequired = false,
  });

  @override
  State<EditablePasswordField> createState() => _EditablePasswordFieldState();
}

class _EditablePasswordFieldState extends State<EditablePasswordField> {
  bool _passwordHidden = true;

  /// Regular expression for password that checks for at least 6 characters, 
  /// one uppercase letter, one lowercase letter, one number and one special character.
  final _passwordRegex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{6,}$');

  @override
  Widget build(BuildContext context) {
    return EditableTextField(
      initialValue: widget.initialValue,
      onChanged: widget.onChanged,
      obscureText: _passwordHidden,
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        border: const OutlineInputBorder(),
        labelText: widget.decoration?.labelText ?? 'Password',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(_passwordHidden ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _passwordHidden = !_passwordHidden),
        ),
      ),
      isEditable: true,
      textStyle: widget.textStyle,
      validator: (value) {
        // Return null if empty (standard optional field behavior)
        if (value == null || value.isEmpty) {
          return widget.isRequired ? 'Password is required' : null;
        }

        // Check minimum length        
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }

        // Check regex for complexity
        if (!_passwordRegex.hasMatch(value)) {
          return 'Password must contain uppercase, lowercase, number and special character';
        }

        // Custom external validation
        if (widget.validator != null) {
          return widget.validator!(value);
        }

        return null;
      },
    );
  }
}
