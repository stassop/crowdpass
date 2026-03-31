import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';

// Firestore limits and Web Safe Integer limits
const num _defaultMin = 0;
// 2^53 - 1 is the max safe integer in JavaScript (Flutter Web).
// If you are purely native, you could use 9223372036854775807 (Dart's max int).
const num _defaultMaxInt = 9007199254740991;

class EditableNumberField extends StatefulWidget {
  final num? min;
  final num? max;
  final bool hasDecimals;
  final InputDecoration? decoration;
  final num? initialValue;
  final void Function(num)? onChanged;
  final String? Function(num?)? validator;
  final bool isRequired;
  final bool isEditable;

  const EditableNumberField({
    super.key,
    this.min = _defaultMin,
    this.max,
    this.hasDecimals = false,
    this.decoration,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.isRequired = false,
    this.isEditable = true,
  });

  @override
  State<EditableNumberField> createState() => _EditableNumberFieldState();
}

class _EditableNumberFieldState extends State<EditableNumberField> {
  late TextEditingController _controller;
  late num _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue ?? 0;

    // Don't show '0' if it's not required and has no initial value
    final initialText = (widget.initialValue == null && !widget.isRequired)
        ? ''
        : _value.toString();

    _controller = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) return;

    final parsedValue = widget.hasDecimals
        ? double.tryParse(text)
        : int.tryParse(text);

    if (parsedValue != null) {
      setState(() {
        _value = parsedValue;
      });
      widget.onChanged?.call(_value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the absolute max based on whether it's a decimal or integer
    final num absoluteMax =
        widget.max ?? (widget.hasDecimals ? double.maxFinite : _defaultMaxInt);

    return EditableTextField(
      controller: _controller,
      isEditable: widget.isEditable,
      textStyle: Theme.of(context).textTheme.bodyLarge,
      keyboardType: widget.hasDecimals
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        // Prevents letters and negative signs (enforcing min 0 at the keyboard level)
        FilteringTextInputFormatter.allow(
          RegExp(widget.hasDecimals ? r'[0-9.]' : r'[0-9]'),
        ),
        // If decimals are allowed, prevent entering more than one decimal point
        if (widget.hasDecimals)
          TextInputFormatter.withFunction((oldValue, newValue) {
            final text = newValue.text;
            if (text.characters.where((c) => c == '.').length > 1) {
              return oldValue;
            }
            return newValue;
          }),
      ],
      onChanged: _onTextChanged,
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        prefixIcon: widget.decoration?.prefixIcon ?? const Icon(Icons.numbers),
        labelText: widget.decoration?.labelText ?? 'Enter number',
      ),
      validator: (text) {
        final isEmpty = text == null || text.trim().isEmpty;

        if (isEmpty) {
          if (widget.isRequired) return 'This field is required';
          return null; // Valid if empty and not required
        }

        final parsedValue = widget.hasDecimals
            ? double.tryParse(text)
            : int.tryParse(text);

        // Custom validator takes precedence if provided
        if (widget.validator != null) {
          return widget.validator!(parsedValue);
        }

        if (parsedValue == null) {
          return 'Invalid number';
        }

        final effectiveMin = widget.min ?? _defaultMin;

        if (parsedValue < effectiveMin) {
          return 'Must be ≥ $effectiveMin';
        }

        if (parsedValue > absoluteMax) {
          return 'Must be ≤ $absoluteMax';
        }

        return null;
      },
    );
  }
}
