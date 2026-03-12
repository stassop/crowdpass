import 'package:flutter/material.dart';

import 'package:crowdpass/widgets/animated_dialog.dart';
import 'package:crowdpass/widgets/location_map.dart';
import 'package:crowdpass/widgets/editable_text_field.dart';

import 'package:crowdpass/models/location.dart';

class EditableLocationField extends StatefulWidget {
  const EditableLocationField({
    super.key,
    this.decoration,
    this.initialValue,
    this.isEditable = false,
    this.onChanged,
    this.textStyle,
    this.title,
    this.validator,
  });

  final Location? initialValue;
  final bool isEditable;
  final String? title;
  final TextStyle? textStyle;
  final InputDecoration? decoration;
  final String? Function(Location?)? validator;
  final Function(Location)? onChanged;

  @override
  State<StatefulWidget> createState() => _EditableLocationFieldState();
}

class _EditableLocationFieldState extends State<EditableLocationField> {
  Location? _location;
  bool _isChanged = false;

  Future<void> _showLocationMap() async {
    await AnimatedDialog.show(
      context: context,
      title: Text(widget.title ?? 'Select Location'),
      contentPadding: EdgeInsets.zero,
      content: StatefulBuilder(
        builder: (context, setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: MediaQuery.of(context).size.width,
                child: LocationMap(
                  location: _location,
                  onLocationChanged: (Location location) {
                    setState(() {
                      _location = location;
                      _isChanged = true;
                    });
                  },
                ),
              ),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextButton.icon(
                  onPressed: () {
                    if (_location != null && _isChanged) {
                      widget.onChanged?.call(_location!);
                    }
                    Navigator.of(context).pop();
                  },
                  icon: Icon(_isChanged ? Icons.check : Icons.close),
                  label: Text(_isChanged ? 'Save' : 'Close'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _location = widget.initialValue;
  }

  @override
  void didUpdateWidget(EditableLocationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      setState(() {
        _location = widget.initialValue;
        _isChanged = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return EditableTextField(
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        prefixIcon: Icon(Icons.location_pin),
        labelText: widget.decoration?.labelText ?? 'Location',
      ),
      isEditable: widget.isEditable,
      isMultiline: true,
      onTap: widget.isEditable ? _showLocationMap : null,
      readOnly: true,
      textStyle: widget.textStyle,
      initialValue: _location?.fullName,
      validator: (_) => widget.validator?.call(_location),
    );
  }
}
