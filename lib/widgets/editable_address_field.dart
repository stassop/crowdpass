import 'dart:async';
import 'package:flutter/material.dart';
import 'package:crowdpass/services/location_service.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/widgets/debounced_search_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';

class EditableAddressField extends StatefulWidget {
  const EditableAddressField({
    super.key,
    this.isEditable,
    this.location,
    this.onLocationChanged,
    this.validator,
  });

  final bool? isEditable;
  final Location? location;
  final Function(Location? location)? onLocationChanged;
  final String? Function(Location? value)? validator;

  @override
  State<StatefulWidget> createState() => _EditableAddressFieldState();
}

class _EditableAddressFieldState extends State<EditableAddressField> {
  Location? _selectedLocation;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.location;
  }

  @override
  void didUpdateWidget(EditableAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.location != oldWidget.location) {
      setState(() => _selectedLocation = widget.location);
    }
  }

  void _updateLocation(Location? location) {
    setState(() => _selectedLocation = location);
    widget.onLocationChanged?.call(location);
  }

  Future<List<Location>> _searchLocation(String query) async {
    try {
      return await LocationService.searchLocation(query);
    } catch (error) {
      // Logic: Only show dialog for hard errors, not empty results
      debugPrint('Search error: $error');
      return [];
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isLocating) return; // Prevent multiple simultaneous GPS requests

    setState(() => _isLocating = true);

    try {
      final location = await LocationService.getCurrentLocation();
      if (mounted) {
        _updateLocation(location);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DebouncedSearchField<Location>(
      initialValue: _selectedLocation,
      isEditable: widget.isEditable,
      validator: widget.validator,
      // We pass the GPS button through the decoration
      decoration: InputDecoration(
        labelText: 'Address',
        border: const OutlineInputBorder(),
        prefixIcon: _isLocating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: Icon(Icons.my_location, color: theme.colorScheme.primary),
                onPressed: _getCurrentLocation,
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
      onResultSelected: _updateLocation,
    );
  }
}
