import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A customizable editable text field widget that supports controlled or internal
/// text editing, multiline input, validation, and read-only modes.
///
/// - If [controller] is provided, this widget uses it and does not manage text state internally.
/// - If [controller] is null, an internal [TextEditingController] is created and managed.
/// - The [initialValue] property is only used to initialize or update the internal controller's text
///   when no external controller is supplied.
/// - The field is read-only if [isEditable] is false or [readOnly] is true.
///

class EditableTextField extends StatefulWidget {
  const EditableTextField({
    super.key,
    this.autovalidateMode,
    this.controller,
    this.decoration,
    this.focusNode,
    this.initialValue,
    this.inputFormatters,
    this.isEditable = false,
    this.isMultiline = false,
    this.isRequired = false,
    this.keyboardType,
    this.maxLength,
    this.minLines,
    this.obscureText = false,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.textStyle,
    this.validator,
  });

  final AutovalidateMode? autovalidateMode;
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final FocusNode? focusNode;
  final String? initialValue;
  final List<TextInputFormatter>? inputFormatters;
  final bool isEditable;
  final bool isMultiline;
  final bool isRequired;
  final int? maxLength;
  final int? minLines;
  final TextInputType? keyboardType;
  final bool obscureText;
  final void Function()? onTap;
  final void Function(String)? onChanged;
  final bool readOnly;
  final TextStyle? textStyle;
  final String? Function(String?)? validator;

  @override
  State<EditableTextField> createState() => _EditableTextFieldState();
}

class _EditableTextFieldState extends State<EditableTextField> {
  late final TextEditingController _controller;
  late final bool _isExternalController;

  @override
  void initState() {
    super.initState();
    _isExternalController = widget.controller != null;
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant EditableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Prevent changing text during build (which can trigger form rebuilds)
    if (!_isExternalController &&
        widget.initialValue != oldWidget.initialValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.text = widget.initialValue ?? '';
        }
      });
    }
  }

  @override
  void dispose() {
    if (!_isExternalController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autovalidateMode: widget.autovalidateMode,
      controller: _controller,
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        border: widget.isEditable
            ? const OutlineInputBorder()
            : InputBorder.none,
      ),
      focusNode: widget.focusNode,
      inputFormatters: widget.inputFormatters,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      maxLength: widget.isEditable ? widget.maxLength : null,
      maxLines: widget.isMultiline ? null : 1,
      minLines: widget.isMultiline ? (widget.minLines ?? 1) : 1,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      readOnly: !widget.isEditable || widget.readOnly,
      style: widget.textStyle,
      validator: (value) {
        if (widget.isRequired && (value == null || value.isEmpty)) {
          return 'This field is required';
        }
        if (widget.validator != null) {
          return widget.validator!(value);
        }
        return null;
      },
    );
  }
}
