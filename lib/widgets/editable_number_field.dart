import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';

// Firestore uses 64-bit integers, but Flutter Web (JavaScript) 
// has a safe integer limit of 2^53 - 1. 
const num _defaultMin = 0;
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
    this.max = _defaultMaxInt,
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
        FilteringTextInputFormatter.allow(
          RegExp(widget.hasDecimals ? r'[0-9.]' : r'[0-9]'),
        ),
        if (widget.hasDecimals)
          TextInputFormatter.withFunction((oldValue, newValue) {
            final text = newValue.text;
            if (text.characters.where((c) => c == '.').length > 1) {
              return oldValue;
            }
            return newValue;
          }),
        // Prevents entering a value that exceeds the absolute maximum
        TextInputFormatter.withFunction((oldValue, newValue) {
          if (newValue.text.isEmpty) return newValue;
          final val = widget.hasDecimals 
              ? double.tryParse(newValue.text) 
              : int.tryParse(newValue.text);
          if (val != null && val > absoluteMax) {
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
          return null;
        }

        final parsedValue = widget.hasDecimals
            ? double.tryParse(text)
            : int.tryParse(text);

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

        // Final boundary check upon submission
        if (parsedValue > absoluteMax) {
          return 'Must be ≤ $absoluteMax';
        }

        return null;
      },
    );
  }
}