import 'package:flutter/material.dart';

import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/widgets/editable_list_field.dart';

class EditableEventTypeField extends StatelessWidget {
  final String? title;
  final bool isMultiple;
  final bool isEditable;
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
    this.onChanged,
    this.title,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return EditableListField<EventType, EventCategory>(
      categorizedOptions: EventType.byCategory,
      isMultiple: isMultiple,
      isEditable: isEditable,
      initialValue: initialValue,
      title: title ?? 'Event Type',
      getOptionLabel: (option) => option.label,
      getCategoryLabel: (category) => category.label,
      getCategoryIcon: (category) => Icon(category.icon),
      decoration: (decoration ?? const InputDecoration()).copyWith(
        prefixIcon: const Icon(Icons.event),
        labelText: decoration?.labelText ?? 'Event Type',
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }
}