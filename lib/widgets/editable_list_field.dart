import 'package:flutter/material.dart';

import 'package:crowdpass/widgets/animated_dialog.dart';
import 'package:crowdpass/widgets/editable_text_field.dart';

class EditableListField<T, C> extends StatefulWidget {
  const EditableListField({
    super.key,
    this.options,
    this.categorizedOptions,
    this.initialValue,
    this.decoration,
    this.isEditable = false,
    this.isMultiple = false,
    this.onChanged,
    this.textStyle,
    this.title,
    this.validator,
    this.getCategoryIcon,
    this.getCategoryLabel,
    this.getOptionLabel,
    this.getOptionIcon,
  }) : assert(
         options != null || categorizedOptions != null,
         'Either options or categorizedOptions must be provided',
       );

  final Set<T>? options;
  final Map<C, Set<T>>? categorizedOptions;
  final Set<T>? initialValue;
  final bool isEditable;
  final bool isMultiple;
  final InputDecoration? decoration;
  final String? title;
  final TextStyle? textStyle;

  final String? Function(Set<T> selectedOptions)? validator;
  final Function(Set<T> selectedOptions)? onChanged;

  final String Function(T option)? getOptionLabel;
  final Widget Function(T option)? getOptionIcon;
  final String Function(C category)? getCategoryLabel;
  final Widget Function(C category)? getCategoryIcon;

  @override
  State<StatefulWidget> createState() => _EditableListFieldState<T, C>();
}

class _EditableListFieldState<T, C> extends State<EditableListField<T, C>> {
  Set<T> _selectedOptions = {};
  String? _text;
  bool _isChanged = false;

  void _updateText() {
    final sorted = _selectedOptions.toList()
      ..sort((a, b) => a.toString().compareTo(b.toString()));
    _text = sorted.isEmpty
        ? null
        : sorted
            .map((option) => widget.getOptionLabel?.call(option) ?? option.toString())
            .join(', ');
  }

  void _onChanged(T option, bool isSelected) {
    setState(() {
      if (!widget.isMultiple) {
        _selectedOptions = isSelected ? {option} : {};
      } else {
        isSelected ? _selectedOptions.add(option) : _selectedOptions.remove(option);
      }
      _isChanged = !_setEquals(_selectedOptions, widget.initialValue ?? {});
      _updateText();
    });
  }

  Future<void> _showListDialog() async {
    await AnimatedDialog.show(
      context: context,
      barrierDismissible: true,
      title: Text(widget.title ?? 'Select an option'),
      contentPadding: EdgeInsets.zero,
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: MediaQuery.of(context).size.width,
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: widget.categorizedOptions != null
                      ? widget.categorizedOptions!.entries.expand((entry) {
                          final label = widget.getCategoryLabel?.call(entry.key) ?? entry.key.toString();
                          final leading = widget.getCategoryIcon != null
                              ? widget.getCategoryIcon!(entry.key)
                              : null;
                          return [
                            ListTile(
                              title: Text(
                                label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              leading: leading,
                              dense: true,
                              enabled: false,
                            ),
                            ...entry.value.map((option) => _buildOptionTile(option, setDialogState)),
                          ];
                        }).toList()
                      : widget.options!.map((option) => _buildOptionTile(option, setDialogState)).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        if (_isChanged) widget.onChanged?.call(_selectedOptions);
                        Navigator.of(context).pop();
                      },
                      icon: Icon(_isChanged ? Icons.check : Icons.close),
                      label: Text(_isChanged ? 'Save' : 'Close'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOptionTile(T option, void Function(void Function()) setDialogState) {
    final label = widget.getOptionLabel?.call(option) ?? option.toString();
    final icon = widget.getOptionIcon?.call(option);

    return widget.isMultiple
        ? CheckboxListTile(
            value: _selectedOptions.contains(option),
            title: Text(label),
            secondary: icon,
            onChanged: (bool? isSelected) {
              _onChanged(option, isSelected ?? false);
              setDialogState(() {});
            },
          )
        : RadioListTile<T>(
            value: option,
            groupValue: _selectedOptions.isNotEmpty ? _selectedOptions.first : null,
            title: Text(label),
            secondary: icon,
            onChanged: (T? selected) {
              _onChanged(option, true);
              setDialogState(() {});
            },
          );
  }

  @override
  void initState() {
    super.initState();
    final allOptions = widget.options ?? widget.categorizedOptions!.values.expand((s) => s).toSet();
    _selectedOptions = allOptions
        .where((option) => widget.initialValue?.contains(option) ?? false)
        .toSet();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _updateText();
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant EditableListField<T, C> oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newOptions = widget.options ?? widget.categorizedOptions!.values.expand((s) => s).toSet();
    final oldOptions = oldWidget.options ?? oldWidget.categorizedOptions?.values.expand((s) => s).toSet() ?? {};

    final newSelected = widget.initialValue ?? {};
    final oldSelected = oldWidget.initialValue ?? {};

    if (!_setEquals(newOptions, oldOptions) || !_setEquals(newSelected, oldSelected)) {
      _selectedOptions = newOptions.where((o) => newSelected.contains(o)).toSet();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _updateText();
          });
        }
      });
    }
  }

  bool _setEquals(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);

  @override
  Widget build(BuildContext context) {
    return EditableTextField(
      initialValue: _text,
      readOnly: true,
      isMultiline: true,
      isEditable: widget.isEditable,
      onTap: widget.isEditable ? _showListDialog : null,
      textStyle: widget.textStyle,
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
      validator: (_) => widget.validator?.call(_selectedOptions),
    );
  }
}
