import 'package:flutter/material.dart';

import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/widgets/editable_list_field.dart';

class EditableEventTypeField extends StatefulWidget {
  final String? title;
  final bool isMultiple;
  final bool isEditable;
  final bool isRequired;
  final InputDecoration? decoration;
  final Set<EventType>? initialValue;
  final ValueChanged<Set<EventType>>? onChanged;
  final String? Function(Set<EventType>)? validator;

  const EditableEventTypeField({
    super.key,
    this.decoration,
    this.initialValue,
    this.isEditable = false,
    this.isMultiple = false,
    this.isRequired = false,
    this.onChanged,
    this.title,
    this.validator,
  });

  @override
  State<EditableEventTypeField> createState() => _EditableEventTypeFieldState();
}

class _EditableEventTypeFieldState extends State<EditableEventTypeField> {
  late Set<EventType> _selectedEvents; // Local state for selected events

  @override
  void initState() {
    super.initState();
    _selectedEvents =
        widget.initialValue ?? {}; // Initialize with initialValue or empty set
  }

  void _onChanged(Set<EventType> value) {
    setState(() {
      _selectedEvents = value; // Update local state
    });
    widget.onChanged?.call(value); // Trigger external onChanged callback
  }

  @override
  Widget build(BuildContext context) {
    final EventType? firstSelected = _selectedEvents.isNotEmpty
        ? _selectedEvents.first
        : null;
    final Icon? prefixIcon = firstSelected != null
        ? Icon(firstSelected.category.icon) // Use the icon of the first selected event's category
        : const Icon(Icons.category); // Default icon if no event is selected

    return EditableListField<EventType, EventCategory>(
      categorizedOptions: EventType.byCategory,
      isMultiple: widget.isMultiple,
      isEditable: widget.isEditable,
      initialValue: _selectedEvents,
      title: widget.title ?? 'Event Type',
      getOptionLabel: (option) => option.label,
      getCategoryLabel: (category) => category.label,
      getCategoryIcon: (category) => Icon(category.icon),
      decoration: (widget.decoration ?? const InputDecoration()).copyWith(
        prefixIcon:
            prefixIcon, // Use dynamic prefixIcon based on selected event
        labelText: widget.decoration?.labelText ?? 'Event Type',
      ),
      onChanged: _onChanged,
      validator: (value) {
        if (widget.isRequired && value.isEmpty) {
          return 'Please select at least one event type';
        }
        if (widget.validator != null) {
          return widget.validator!(value);
        }
        return null;
      },
    );
  }
}
