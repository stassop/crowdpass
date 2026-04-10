import 'package:flutter/material.dart';

import 'package:crowdpass/services/date_time_service.dart';
import 'package:crowdpass/widgets/editable_text_field.dart';

class EditableDateRangeField extends StatefulWidget {
  EditableDateRangeField({
    super.key,
    this.initialValue,
    this.isEditable = false,
    this.isRequired = false,
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
  final bool isRequired;
  final InputDecoration? decoration;
  final String? title;
  final TextStyle? textStyle;
  final String? Function(DateTimeRange?)? validator;
  final Function(DateTimeRange)? onChanged;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<EditableDateRangeField> createState() => _DateRangeFieldState();
}

class _DateRangeFieldState extends State<EditableDateRangeField> {
  DateTimeRange? _dateRange;
  late final TextEditingController _controller;

  bool _syncScheduled = false;

  String _format(DateTimeRange? range) {
    if (range == null) return '';
    return DateTimeService.formatDateTimeRange(range);
  }

  void _syncTextController() {
    final text = _format(_dateRange);
    if (_controller.text == text) return;

    _controller.value = _controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  void _syncController({required bool deferIfBuilding}) {
    // If we're currently in build/layout/paint, a controller write can trigger
    // Form/TextFormField notifications -> "markNeedsBuild during build".
    // So coalesce one post-frame update.
    if (deferIfBuilding) {
      if (_syncScheduled) return;
      _syncScheduled = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncScheduled = false;
        if (!mounted) return;
        _syncTextController();
      });
      return;
    }

    _syncTextController();
  }

  Future<void> _showDateTimeRangePicker() async {
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      initialEntryMode: DatePickerEntryMode.calendar,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: widget.title,
      builder: (BuildContext context, Widget? child) {
        final animation = CurvedAnimation(
          parent: ModalRoute.of(context)?.animation ??
              const AlwaysStoppedAnimation(1),
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

    if (!mounted) return;

    if (pickedRange != null && pickedRange != _dateRange) {
      setState(() {
        _dateRange = pickedRange;
      });

      // After closing the picker route we're often mid-transition builds.
      _syncController(deferIfBuilding: true);

      widget.onChanged?.call(pickedRange);
    }
  }

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialValue;
    _controller = TextEditingController(text: _format(_dateRange));
  }

  @override
  void didUpdateWidget(covariant EditableDateRangeField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialValue != widget.initialValue) {
      _dateRange = widget.initialValue;

      // didUpdateWidget is called during rebuild; treat as "defer if building"
      // to avoid Form markNeedsBuild assertions.
      _syncController(deferIfBuilding: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EditableTextField(
      controller: _controller,
      readOnly: true,
      textStyle: widget.textStyle,
      isEditable: widget.isEditable,
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        labelText: widget.decoration?.labelText ?? 'Dates',
        prefixIcon: const Icon(Icons.date_range),
      ),
      onTap: widget.isEditable ? _showDateTimeRangePicker : null,
      validator: (_) {
        if (widget.isRequired && _dateRange == null) {
          return 'Please select a date range';
        }
        if (widget.validator != null) {
          return widget.validator!(_dateRange);
        }
        return null;
      },
    );
  }
}