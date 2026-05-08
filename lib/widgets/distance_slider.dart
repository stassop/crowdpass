import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LengthUnit;

class DistanceUnitValue {
  final LengthUnit unit;
  final double value;

  DistanceUnitValue({required this.unit, required this.value});

  @override
  String toString() => '$value ${unit.scaleFactor}'; 
}

class DistanceSlider extends StatefulWidget {
  final double min;
  final double max;
  final double? initialValue;
  final LengthUnit? initialUnit;
  final int? divisions;
  final ValueChanged<LengthUnit>? onUnitChanged;
  final ValueChanged<double>? onValueChanged;
  final FormFieldValidator<double>? validator;
  final FormFieldSetter<double>? onSaved;
  final AutovalidateMode autovalidateMode;

  const DistanceSlider({
    super.key,
    this.min = 0,
    this.max = 100,
    this.initialValue,
    this.initialUnit,
    this.onUnitChanged,
    this.onValueChanged,
    this.divisions,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
  });

  @override
  State<DistanceSlider> createState() => _DistanceSliderState();
}

class _DistanceSliderState extends State<DistanceSlider> {
  late double _value;
  late LengthUnit _unit;

  final Map<LengthUnit, String> _unitLabels = const {
    LengthUnit.Meter: 'm',
    LengthUnit.Kilometer: 'km',
    LengthUnit.Mile: 'mi',
  };

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit ?? LengthUnit.Kilometer;
    _value = widget.initialValue ?? widget.max;
  }

  void _handleUpdate(double newValue, FormFieldState<double> state) {
    setState(() => _value = newValue);
    state.didChange(newValue);
  }

  void _handleUnitChange(LengthUnit newUnit, FormFieldState<double> state) {
    setState(() {
      final convertedValue = _unit.to(newUnit, _value);
      _value = convertedValue.clamp(widget.min, widget.max);
      _unit = newUnit;
    });
    state.didChange(_value);
    widget.onUnitChanged?.call(_unit);
  }

  @override
  Widget build(BuildContext context) {
    final divisions = widget.divisions ?? 10;
    return FormField<double>(
      initialValue: _value,
      validator: widget.validator,
      onSaved: widget.onSaved,
      autovalidateMode: widget.autovalidateMode,
      builder: (FormFieldState<double> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: widget.min,
                    max: widget.max,
                    divisions: divisions,
                    value: _value.clamp(widget.min, widget.max),
                    label: '${_value.toStringAsFixed(1)} ${_unitLabels[_unit]}',
                    onChanged: (double value) => _handleUpdate(value, state),
                    onChangeEnd: (double value) {
                      widget.onValueChanged?.call(value);
                    },
                  ),
                ),
                MenuAnchor(
                  builder: (context, controller, child) => TextButton(
                    onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                    child: Text(
                      '${_value.toStringAsFixed(1)} ${_unitLabels[_unit]}',
                    ),
                  ),
                  menuChildren: _unitLabels.entries.map((entry) =>
                    MenuItemButton(
                      onPressed: () => _handleUnitChange(entry.key, state),
                      child: Text(entry.value),
                    )
                  ).toList(),
                ),
              ],
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  state.errorText ?? '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}