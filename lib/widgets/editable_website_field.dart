import 'package:flutter/material.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';

/// A specialized [EditableTextField] for website input.
class EditableWebsiteField extends StatelessWidget {
  const EditableWebsiteField({
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
  static final Pattern _websitePattern = RegExp(
    r"^(https?:\/\/)?([\w-]+\.)+[\w-]{2,}(\/[^\s]*)?$",
  );

  @override
  Widget build(BuildContext context) {
    return EditableTextField(
      initialValue: initialValue,
      isEditable: isEditable,
      keyboardType: TextInputType.url,
      textStyle: textStyle,
      decoration: (decoration ?? const InputDecoration()).copyWith(
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.web),
        labelText: decoration?.labelText ?? 'Website',
      ),
      validator: (value) {
        // 1. Return null if empty (standard optional field behavior)
        if (value == null || value.isEmpty) {
          return isRequired ? 'Website is required' : null;
        }

        // 2. Validation using the Pattern interface.
        // allMatches returns an Iterable; if it's empty, the website is invalid.
        if (_websitePattern.allMatches(value).isEmpty) {
          return 'Enter a valid website URL';
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
