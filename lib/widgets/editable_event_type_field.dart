import 'package:flutter/material.dart';

import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/widgets/editable_list_field.dart';

class EditableEventTypeField extends StatelessWidget {
  final bool isMultiple;
  final bool isEditable;
  final Set<EventType>? initialValue;
  final ValueChanged<Set<EventType>> onChanged;
  final InputDecoration? decoration;
  final String? title;
  final String? Function(Set<EventType>)? validator;

  const EditableEventTypeField({
    super.key,
    this.isMultiple = false,
    required this.isEditable,
    required this.initialValue,
    required this.onChanged,
    this.decoration,
    this.title,
    this.validator,
  });

  Icon _getCategoryIcon(EventCategory category) {
    switch (category) {
      case EventCategory.music:
        return const Icon(Icons.music_note);
      case EventCategory.art:
        return const Icon(Icons.brush);
      case EventCategory.sports:
        return const Icon(Icons.sports_soccer);
      case EventCategory.food:
        return const Icon(Icons.restaurant);
      case EventCategory.education:
        return const Icon(Icons.school);
      case EventCategory.networking:
        return const Icon(Icons.people);
      case EventCategory.social:
        return const Icon(Icons.group);
      case EventCategory.other:
        return const Icon(Icons.event);
      default:
        return const Icon(Icons.event);
    }
  }

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
      getCategoryIcon: _getCategoryIcon,
      decoration: (decoration ?? const InputDecoration()).copyWith(
        prefixIcon: const Icon(Icons.event),
        labelText: decoration?.labelText ?? 'Event Type',
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }
}