import 'package:flutter/material.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';

import 'package:crowdpass/models/time_range.dart';

class EditableTimeRangeField extends StatefulWidget {
  const EditableTimeRangeField({
    super.key,
    this.initialValue,
    this.start,
    this.end,
    this.startTitle = 'Start Time',
    this.endTitle = 'End Time',
    this.isEditable = false,
    this.onChanged,
    this.textStyle,
    this.validator,
    this.decoration,
  });

  final TimeRange? initialValue;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final String startTitle;
  final String endTitle;
  final bool isEditable;
  final InputDecoration? decoration;
  final TextStyle? textStyle;
  final String? Function(TimeRange?)? validator;
  final void Function(TimeRange)? onChanged;

  @override
  State<EditableTimeRangeField> createState() =>
      _EditableTimeRangeFieldState();
}

class _EditableTimeRangeFieldState
    extends State<EditableTimeRangeField> {
  TimeRange? _timeRange;

  @override
  void initState() {
    super.initState();
    _timeRange = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant EditableTimeRangeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _timeRange = widget.initialValue;
    }
  }

  Future<void> _showTimeRangePicker() async {
    // 1. Pick Start Time
    final TimeOfDay? pickedStart = await showTimePicker(
      context: context,
      initialTime: _timeRange?.start ?? TimeOfDay(hour: 6, minute: 0),
      helpText: widget.startTitle,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              helpTextStyle:
                  Theme.of(context).textTheme.titleLarge,
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || pickedStart == null) return;

    // Validate start lower bound
    if (widget.start != null &&
        pickedStart.isBefore(widget.start!)) {
      _showSnackBar(
        'Start time cannot be before '
        '${widget.start!.format(context)}',
      );
      return;
    }

    // 2. Pick End Time
    final TimeOfDay? pickedEnd = await showTimePicker(
      context: context,
      initialTime: _timeRange?.end ?? TimeOfDay(hour: 18, minute: 0),
      helpText: widget.endTitle,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              helpTextStyle:
                  Theme.of(context).textTheme.titleLarge,
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || pickedEnd == null) return;

    // Validate end upper bound
    if (widget.end != null &&
        pickedEnd.isAfter(widget.end!)) {
      _showSnackBar(
        'End time cannot be after '
        '${widget.end!.format(context)}',
      );
      return;
    }

    // Validate range ordering
    if (pickedEnd.compareTo(pickedStart) <= 0) {
      _showSnackBar('End time must be after start time.');
      return;
    }

    // 3. Update State
    final newTimeRange =
        TimeRange(start: pickedStart, end: pickedEnd);

    setState(() => _timeRange = newTimeRange);
    widget.onChanged?.call(newTimeRange);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EditableTextField(
      initialValue: _timeRange?.toString(),
      readOnly: true,
      textStyle: widget.textStyle,
      isEditable: widget.isEditable,
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        labelText: widget.decoration?.labelText ?? 'Time Range',
        prefixIcon: const Icon(Icons.access_time),
      ),
      onTap: widget.isEditable ? _showTimeRangePicker : null,
      validator: (_) => widget.validator?.call(_timeRange),
    );
  }
}
