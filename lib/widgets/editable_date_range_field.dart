import 'package:flutter/material.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';

import 'package:crowdpass/services/date_time_service.dart';

class EditableDateRangeField extends StatefulWidget {
  EditableDateRangeField({
    super.key,
    this.initialValue,
    this.isEditable = false,
    this.onChanged,
    this.textStyle,
    this.title,
    this.validator,
    this.decoration,
    DateTime? firstDate,
    DateTime? lastDate,
  })  : firstDate = firstDate ?? DateTime.now(),
        lastDate = lastDate ?? DateTime.now().add(const Duration(days: 365));

  final DateTimeRange? initialValue;
  final bool isEditable;
  final InputDecoration? decoration;
  final String? title;
  final TextStyle? textStyle;
  final String? Function(DateTimeRange?)? validator;
  final Function(DateTimeRange)? onChanged;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<StatefulWidget> createState() => _DateRangeFieldState();
}

class _DateRangeFieldState extends State<EditableDateRangeField> {
  DateTimeRange? _dateRange;

  void _showDateTimeRangePicker() async {
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      initialEntryMode: DatePickerEntryMode.calendar,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: widget.title,
      builder: (BuildContext context, Widget? child) {
        final animation = CurvedAnimation(
          parent: ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation(1),
          curve: Curves.easeOut,
        );
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final scaleTween = Tween<double>(begin: 0.5, end: 1.0);
            final opacityTween = Tween<double>(begin: 0.5, end: 1.0);
            return Transform.scale(
              scale: animation.drive(scaleTween).value,
              child: Opacity(
                opacity: animation.drive(opacityTween).value,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
    );

    if (pickedRange != null && pickedRange != _dateRange) {
      setState(() {
        _dateRange = pickedRange;
      });
      widget.onChanged?.call(pickedRange);
    }
  }

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant EditableDateRangeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setState(() {
        _dateRange = widget.initialValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateRangeText = _dateRange != null
      ? DateTimeService.formatDateTimeRange(_dateRange!)
      : null;

    return EditableTextField(
      initialValue: dateRangeText,
      readOnly: true,
      textStyle: widget.textStyle,
      isEditable: widget.isEditable,
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        labelText: widget.decoration?.labelText ?? 'Date Range',
        prefixIcon: const Icon(Icons.date_range),
      ),
      onTap: widget.isEditable ? _showDateTimeRangePicker : null,
      validator: (_) => widget.validator?.call(_dateRange),
    );
  }
}
