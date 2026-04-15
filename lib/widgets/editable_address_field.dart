import 'dart:async';
import 'package:flutter/material.dart';
import 'package:crowdpass/services/location_service.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/widgets/debounced_search_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';

class EditableAddressField extends StatefulWidget {
  const EditableAddressField({
    super.key,
    this.isEditable = false,
    this.isRequired = false,
    this.location,
    this.onChanged,
    this.validator,
    this.onSaved,
  });

  final bool isEditable;
  final bool isRequired;
  final Location? location;
  final Function(Location? location)? onChanged;
  final String? Function(Location? value)? validator;
  final FormFieldSetter<Location>? onSaved;

  @override
  State<EditableAddressField> createState() => _EditableAddressFieldState();
}

class _EditableAddressFieldState extends State<EditableAddressField> {
  Location? _selectedLocation;
  bool _isLocating = false;
  
  // Use a GlobalKey to manually trigger didChange on the FormField
  final GlobalKey<FormFieldState<Location>> _fieldKey = GlobalKey<FormFieldState<Location>>();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.location;
  }

  @override
  void didUpdateWidget(EditableAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != oldWidget.location) {
      _selectedLocation = widget.location;
      // This ensures the FormField internal state updates when the parent prop changes
      _fieldKey.currentState?.didChange(widget.location);
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
      final location = await LocationService.getCurrentLocation();
      if (mounted) {
        _handleNewLocation(location);
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

  void _handleNewLocation(Location? location) {
    setState(() => _selectedLocation = location);
    _fieldKey.currentState?.didChange(location);
    widget.onChanged?.call(location);
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
          return 'Please select a location';
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
              decoration: InputDecoration(
                labelText: 'Address',
                border: const OutlineInputBorder(),
                errorText: state.errorText,
                prefixIcon: _isLocating
                    ? const CircularProgressIndicator()
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