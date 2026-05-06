import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show Distance, LengthUnit;

class DistanceSlider extends StatefulWidget {
  final double min;
  final double max;
  final int? divisions;
  final double? initialValue;
  final Distance? initialDistance;
  final LengthUnit? units;

  final ValueChanged<Distance>? onChanged;
  final FormFieldValidator<double>? validator;
  final FormFieldSetter<double>? onSaved;
  final AutovalidateMode autovalidateMode;

  const DistanceSlider({
    super.key,
    required this.min,
    required this.max,
    this.initialValue,
    this.initialDistance,
    this.units,
    this.onChanged,
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
  late LengthUnit _currentUnit;

  @override
  void initState() {
    super.initState();
    // Priority: initialValue > initialDistance > min
    _value = widget.initialValue ?? widget.min;
    _currentUnit = widget.units ?? LengthUnit.Kilometer;
  }

  // Calculate meters using the scale factor from the provided LengthUnit class
  double get _meters => _currentUnit.to(LengthUnit.Meter, _value);

  String _formatLabel(double value, LengthUnit unit) {
    String suffix = 'm';
    if (unit == LengthUnit.Kilometer) suffix = 'km';
    if (unit == LengthUnit.Mile) suffix = 'mi';
    return '${value.toStringAsFixed(1)} $suffix';
  }

  void _notifyChange(FormFieldState<double> state) {
    state.didChange(_meters);
    if (widget.onChanged != null) {
      // Returning the calculator instance as requested
      widget.onChanged!(widget.initialDistance ?? const Distance());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<double>(
      initialValue: _meters,
      validator: widget.validator,
      onSaved: widget.onSaved,
      autovalidateMode: widget.autovalidateMode,
      builder: (FormFieldState<double> state) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Slider(
                    min: widget.min,
                    max: widget.max,
                    divisions: widget.divisions,
                    value: _value,
                    label: _formatLabel(_value, _currentUnit),
                    onChanged: (val) {
                      setState(() => _value = val);
                      _notifyChange(state);
                    },
                  ),
                ),
                DropdownButton<LengthUnit>(
                  value: _currentUnit,
                  onChanged: (unit) {
                    if (unit != null) {
                      setState(() => _currentUnit = unit);
                      _notifyChange(state);
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: LengthUnit.Meter, child: Text('m')),
                    DropdownMenuItem(value: LengthUnit.Kilometer, child: Text('km')),
                    DropdownMenuItem(value: LengthUnit.Mile, child: Text('mi')),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}