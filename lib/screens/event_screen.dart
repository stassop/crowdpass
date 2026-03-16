import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/event_provider.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';
import 'package:crowdpass/widgets/editable_date_range_field.dart';
import 'package:crowdpass/widgets/editable_time_range_field.dart';
import 'package:crowdpass/widgets/editable_address_field.dart';
import 'package:crowdpass/widgets/editable_event_type_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';

class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({super.key});

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  String? _eventId;
  Event? _eventCopy;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely extract the Event ID from route arguments
    if (!_initialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _eventId = args;
      } else {
        // If no ID is passed, we are in "Create" mode by default
        _isEditing = true;
        _eventCopy = Event();
      }
      _initialized = true;
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _eventCopy == null) return;

    try {
      if (_eventId == null) {
        await ref.read(eventNotifier.notifier).createEvent(_eventCopy!);
      } else {
        await ref.read(eventNotifier.notifier).updateEvent(_eventCopy!);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, title: 'Save Failed', message: 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final eventAsync = ref.watch(eventProvider(_eventId));

    return authAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_eventId == null ? 'New Event' : 'Event Details'),
            leading: BackButton(
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: Center(child: Text('Auth Error: $err')),
        );
      },
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_eventId == null ? 'New Event' : 'Event Details'),
              leading: BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: const Center(child: Text('Please sign in.')),
          );
        }

        final isOrganizer =
            ref.watch(companyProvider(user.uid)).value != null;

        return eventAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(
            appBar: AppBar(
              title: Text(_eventId == null ? 'New Event' : 'Event Details'),
              leading: BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: Center(child: Text('Error: $err')),
          ),
          data: (event) {
            final isCreating = event == null;
            // Initialize copy from network data if we haven't started editing yet
            if (_eventCopy == null && event != null) {
              _eventCopy = event;
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(_eventId == null ? 'New Event' : 'Event Details'),
                actions: [
                  if (isOrganizer)
                    IconButton(
                      icon: Icon(_isEditing ? Icons.check : Icons.edit),
                      onPressed: () {
                        if (_isEditing) {
                          _handleSave();
                        } else {
                          setState(() => _isEditing = true);
                        }
                      },
                    ),
                ],
              ),
              body: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EditableTextField(
                        initialValue: _eventCopy?.title,
                        isEditable: _isEditing,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (val) =>
                            (val == null || val.isEmpty) ? 'Required' : null,
                        onChanged: (val) =>
                            _eventCopy = _eventCopy?.copyWith(title: val),
                      ),

                      const SizedBox(height: 16),

                      EditableTextField(
                        initialValue: _eventCopy?.description,
                        isEditable: _isEditing,
                        minLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (val) =>
                            (val == null || val.isEmpty) ? 'Required' : null,
                        onChanged: (val) =>
                            _eventCopy = _eventCopy?.copyWith(description: val),
                      ),

                      const SizedBox(height: 16),

                      EditableEventTypeField(
                        initialValue: _eventCopy?.type != null
                            ? {_eventCopy!.type!}
                            : {},
                        isEditable: _isEditing,
                        onChanged: (types) => _eventCopy = _eventCopy?.copyWith(
                          type: types.firstOrNull,
                        ),
                        validator: (types) =>
                            types.isEmpty ? 'Select a type' : null,
                      ),

                      const SizedBox(height: 16),

                      EditableAddressField(
                        location: _eventCopy?.location,
                        isEditable: _isEditing,
                        onLocationChanged: (location) =>
                            _eventCopy = _eventCopy?.copyWith(location: location),
                        validator: (location) =>
                            location == null ? 'Location required' : null,
                      ),

                      const SizedBox(height: 16),

                      EditableDateRangeField(
                        initialValue: _eventCopy?.dates,
                        isEditable: _isEditing,
                        onChanged: (dates) =>
                            _eventCopy = _eventCopy?.copyWith(dates: dates),
                        validator: (dates) =>
                            dates == null ? 'Dates required' : null,
                      ),

                      const SizedBox(height: 16),

                      EditableTimeRangeField(
                        initialValue: _eventCopy?.times,
                        isEditable: _isEditing,
                        onChanged: (times) =>
                            _eventCopy = _eventCopy?.copyWith(times: times),
                        validator: (times) =>
                            times == null ? 'Times required' : null,
                      ),

                      const SizedBox(height: 16),

                      if (isCreating)
                        ElevatedButton(
                          onPressed: _isEditing ? _handleSave : null,
                          child: const Text('Create Event'),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
