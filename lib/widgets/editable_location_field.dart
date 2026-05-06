import 'dart:async';
import 'package:flutter/material.dart';
import 'package:crowdpass/services/location_service.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/widgets/debounced_search_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';

class EditableLocationField extends StatefulWidget {
  const EditableLocationField({
    super.key,
    this.isEditable = false,
    this.isRequired = false,
    this.initialValue,
    this.onChanged,
    this.validator,
    this.onSaved,
    this.decoration,
  });

  final bool isEditable;
  final bool isRequired;
  final Location? initialValue;
  final Function(Location? initialValue)? onChanged;
  final String? Function(Location? value)? validator;
  final FormFieldSetter<Location>? onSaved;
  final InputDecoration? decoration; // <-- Add this

  @override
  State<EditableLocationField> createState() => _EditableLocationFieldState();
}

class _EditableLocationFieldState extends State<EditableLocationField> {
  Location? _selectedLocation;
  bool _isLocating = false;
  
  // Use a GlobalKey to manually trigger didChange on the FormField
  final GlobalKey<FormFieldState<Location>> _fieldKey = GlobalKey<FormFieldState<Location>>();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialValue;
  }

  @override
  void didUpdateWidget(EditableLocationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _selectedLocation = widget.initialValue;
      // This ensures the FormField internal state updates when the parent prop changes
      // We wrap it in addPostFrameCallback to prevent "setState() called during build" errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fieldKey.currentState?.didChange(widget.initialValue);
      });
    }
  }

  Future<List<Location>> _searchLocation(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    try {
      return await LocationService.searchLocation(trimmedQuery);
    } catch (error) {
      debugPrint('Search error: $error');
      return [];
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);

    try {
      final initialValue = await LocationService.getCurrentLocation();
      if (mounted) {
        _handleNewLocation(initialValue);
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().replaceAll('Exception: ', '');
        ErrorDialog.show(
          context,
          title: 'Location Unavailable',
          message: message,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _handleNewLocation(Location? initialValue) {
    setState(() => _selectedLocation = initialValue);
    _fieldKey.currentState?.didChange(initialValue);
    widget.onChanged?.call(initialValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FormField<Location>(
      key: _fieldKey,
      initialValue: _selectedLocation,
      onSaved: widget.onSaved,
      validator: (value) {
        if (widget.isRequired && value == null) {
          return 'Please select a initialValue';
        }
        return widget.validator?.call(value);
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DebouncedSearchField<Location>(
              initialValue: _selectedLocation,
              isEditable: widget.isEditable,
              hintText: 'Search for an address',
              decoration: (widget.decoration ?? const InputDecoration()).copyWith(
                  labelText: 'Address',
                  border: const OutlineInputBorder(),
                  errorText: state.errorText,
                  prefixIcon: _isLocating
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: Icon(Icons.my_location, color: theme.colorScheme.primary),
                          onPressed: widget.isEditable ? _getCurrentLocation : null,
                        ),
                ),
              getDisplayText: (location) => location.fullName,
              tileBuilder: (context, location) {
                return ListTile(
                  leading: const Icon(Icons.location_pin),
                  title: Text(location.shortName, maxLines: 1),
                  subtitle: Text(location.fullName, maxLines: 2),
                );
              },
              searchFunction: _searchLocation,
              onResultSelected: _handleNewLocation,
            ),
          ],
        );
      },
    );
  }
}