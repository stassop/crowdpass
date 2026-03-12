import 'package:flutter/material.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';

/// A specialized [EditableTextField] for email input.
class EditableEmailField extends StatelessWidget {
  const EditableEmailField({
    super.key,
    this.initialValue,
    this.decoration,
    this.onChanged,
    this.textStyle,
    this.validator,
    this.isEditable = true,
    this.isRequired = false,
  });

  final String? initialValue;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final TextStyle? textStyle;
  final FormFieldValidator<String>? validator;
  final bool isEditable;
  final bool isRequired;

  /// Using the 'Pattern' interface as suggested by the deprecation warning.
  /// This keeps the implementation flexible and future-proof.
  static final Pattern _emailPattern = RegExp(
    r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$',
  );

  @override
  Widget build(BuildContext context) {
    return EditableTextField(
      initialValue: initialValue,
      isEditable: isEditable,
      keyboardType: TextInputType.emailAddress,
      textStyle: textStyle,
      decoration: (decoration ?? const InputDecoration()).copyWith(
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.alternate_email),
        labelText: decoration?.labelText ?? 'Email',
      ),
      validator: (value) {
        // 1. Return null if empty (standard optional field behavior)
        if (value == null || value.isEmpty) {
          return isRequired ? 'Email is required' : null;
        }

        // 2. Validation using the Pattern interface.
        // allMatches returns an Iterable; if it's empty, the email is invalid.
        if (_emailPattern.allMatches(value).isEmpty) {
          return 'Enter a valid email address';
        }

        // 3. Custom external validation
        if (validator != null) {
          return validator!(value);
        }

        return null;
      },
      onChanged: onChanged,
    );
  }
}
