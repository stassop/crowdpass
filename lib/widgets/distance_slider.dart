import 'package:flutter/material.dart';
import 'package:crowdpass/models/distance_unit.dart';
import 'package:crowdpass/widgets/unit_menu.dart';

class DistanceSlider extends StatefulWidget {
  final double min;
  final double max;
  final double? initialValue;
  final DistanceUnit? initialUnit;
  final int? divisions;
  final ValueChanged<DistanceUnit>? onUnitChanged;
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
  late double _distance;
  late DistanceUnit _unit;

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit ?? DistanceUnit.kilometer;
    // Defaults to widget.max if initialValue is null
    _distance = (widget.initialValue ?? widget.max).clamp(widget.min, widget.max);
  }

  @override
  Widget build(BuildContext context) {
    final divisions = widget.divisions ?? 10;

    return FormField<double>(
      initialValue: _distance,
      validator: widget.validator,
      onSaved: widget.onSaved,
      autovalidateMode: widget.autovalidateMode,
      builder: (FormFieldState<double> state) {
        // If an external Form.reset() happens, state.value changes back 
        // to initialValue. We sync our local state variable with it here.
        if (state.value != null && state.value != _distance) {
          _distance = state.value!;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UnitMenu<DistanceUnit>(
                  initialUnit: _unit,
                  units: DistanceUnit.units,
                  onUnitChanged: (newUnit) {
                    setState(() => _unit = newUnit);
                    state.didChange(_distance); 
                    widget.onUnitChanged?.call(newUnit);
                  },
                ),
                Expanded(
                  child: Slider(
                    min: widget.min,
                    max: widget.max,
                    divisions: divisions,
                    value: _distance.clamp(widget.min, widget.max),
                    label: '${_distance.toStringAsFixed(1)} ${_unit.symbol}',
                    onChanged: (double value) {
                      setState(() => _distance = value);
                      state.didChange(value);
                    },
                    onChangeEnd: (double value) {
                      widget.onValueChanged?.call(value);
                    },
                  ),
                ),
                Text(
                  '${_distance.toStringAsFixed(1)} ${_unit.symbol}',
                  style: Theme.of(context).textTheme.bodyLarge,
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