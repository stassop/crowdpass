import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/time_range.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/event_provider.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';
import 'package:crowdpass/widgets/editable_address_field.dart';
import 'package:crowdpass/widgets/editable_event_type_field.dart';
import 'package:crowdpass/widgets/editable_date_range_field.dart';
import 'package:crowdpass/widgets/editable_time_range_field.dart';
import 'package:crowdpass/widgets/editable_switch_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';

class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({super.key});

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _admissionStart;
  DateTimeRange? _dates;
  String? _description;
  bool? _isFree;
  bool? _isOutdoor;
  bool? _isWheelchairAccessible;
  Location? _location;
  String? _title;
  EventType? _type;
  TimeRange? _times;
  bool? _isEpilepsyFriendly;
  bool? _isFamilyFriendly;
  bool? _isHearingAidCompatible;
  bool? _isLowSensoryFriendly;
  bool? _isPetFriendly;
  String? _imageURL;

  bool _isEditing = false;
  bool _hasChanged = false;

  void _updateHasChanged(Event? event) {
    _hasChanged =
        _title != event?.title ||
        _description != event?.description ||
        _location != event?.location ||
        _type != event?.type ||
        _dates != event?.dates ||
        _times != event?.times ||
        _isFree != event?.isFree ||
        _isOutdoor != event?.isOutdoor ||
        _isWheelchairAccessible != event?.isWheelchairAccessible ||
        _isEpilepsyFriendly != event?.isEpilepsyFriendly ||
        _isFamilyFriendly != event?.isFamilyFriendly ||
        _isHearingAidCompatible != event?.isHearingAidCompatible ||
        _isLowSensoryFriendly != event?.isLowSensoryFriendly ||
        _isPetFriendly != event?.isPetFriendly ||
        _imageURL != event?.imageURL;
  }
  
  // Set fields from event
  void _resetFields(Event? event) {
    if (event == null) return;
    _title = event.title;
    _description = event.description;
    _location = event.location;
    _type = event.type;
    _dates = event.dates;
    _times = event.times;
    _isFree = event.isFree;
    _isOutdoor = event.isOutdoor;
    _isWheelchairAccessible = event.isWheelchairAccessible;
    _isEpilepsyFriendly = event.isEpilepsyFriendly;
    _isFamilyFriendly = event.isFamilyFriendly;
    _isHearingAidCompatible = event.isHearingAidCompatible;
    _isLowSensoryFriendly = event.isLowSensoryFriendly;
    _isPetFriendly = event.isPetFriendly;
    _imageURL = event.imageURL;
    _updateHasChanged(event);
  }

  Future<void> _createOrUpdate(String? eventId) async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(eventId == null ? 'Creating event...' : 'Updating event...')),
    );

    try {
      if (eventId == null) {
        await ref.read(eventNotifier.notifier).createEvent(
          admissionStart: _admissionStart!,
          dates: _dates!,
          description: _description!,
          imagePath: _imageURL,
          isEpilepsyFriendly: _isEpilepsyFriendly,
          isFamilyFriendly: _isFamilyFriendly,
          isFree: _isFree ?? false,
          isHearingAidCompatible: _isHearingAidCompatible,
          isLowSensoryFriendly: _isLowSensoryFriendly,
          isOutdoor: _isOutdoor ?? false,
          isPetFriendly: _isPetFriendly,
          isWheelchairAccessible: _isWheelchairAccessible ?? false,
          location: _location!,
          times: _times!,
          title: _title!,
          type: _type!,
        );
      } else {
        await ref.read(eventNotifier.notifier).updateEvent(
          admissionStart: _admissionStart!,
          dates: _dates!,
          description: _description!,
          eventId: eventId,
          imagePath: _imageURL,
          isEpilepsyFriendly: _isEpilepsyFriendly,
          isFamilyFriendly: _isFamilyFriendly,
          isFree: _isFree ?? false,
          isHearingAidCompatible: _isHearingAidCompatible,
          isLowSensoryFriendly: _isLowSensoryFriendly,
          isOutdoor: _isOutdoor ?? false,
          isPetFriendly: _isPetFriendly,
          isWheelchairAccessible: _isWheelchairAccessible ?? false,
          location: _location!,
          times: _times!,
          title: _title!,
          type: _type!,
        );
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _imageURL = null; // Reset local image path after success
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, title: 'Failed to save event', message: e.toString());
      }
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventId = ModalRoute.of(context)?.settings.arguments as String?;
    final eventAsync = ref.watch(eventProvider(eventId));
    final user = ref.watch(authProvider).value;

    return eventAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: BackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Center(child: Text('Auth Error: $err')),
      ),
      data: (event) {
        // Set fields from company when new value arrives
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _resetFields(event));
        });

        final isCreating = event == null;
        final isOwner = isCreating || (event.createdBy == user?.uid);
        final isLoading = ref.watch(eventNotifier).isLoading;
        
        // Auto-enable editing for new events
        if (isCreating && !_isEditing) {
          _isEditing = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isCreating
                  ? 'Create Event'
                  : event.title,
            ),
            actions: [
              if (isOwner && !isCreating)
                IconButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (_isEditing && _hasChanged) {
                            _createOrUpdate(event.id);
                          } else {
                            setState(() => _isEditing = !_isEditing);
                          }
                        },
                  icon: Icon(
                    _isEditing
                        ? (_hasChanged ? Icons.check : Icons.close)
                        : Icons.edit,
                  ),
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
                    initialValue: _title,
                    isEditable: _isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _title = value;
                        _updateHasChanged(event);
                      });
                    },
                    validator: (value) {
                      return (value == null || value.isEmpty) ? 'Event title required' : null;
                    },
                  ),

                  const SizedBox(height: 16),

                  EditableTextField(
                    initialValue: _description,
                    isEditable: _isEditing,
                    minLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _description = value;
                        _updateHasChanged(event);
                      });
                    },
                    validator: (value) {
                      return (value == null || value.isEmpty) ? 'Event description required' : null;
                    },
                  ),

                  const SizedBox(height: 16),

                  EditableEventTypeField(
                    initialValue: _type != null ? {_type!} : {},
                    isEditable: _isEditing,
                    isRequired: true,
                    onChanged: (value) { 
                      setState(() {
                        _type = value.isNotEmpty ? value.first : null;
                        _updateHasChanged(event);
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  EditableAddressField(
                    location: _location,
                    isEditable: _isEditing,
                    isRequired: true,
                    onChanged: (value) {
                      setState(() {
                        _location = value;
                        _updateHasChanged(event);
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  EditableDateRangeField(
                    initialValue: _dates,
                    isEditable: _isEditing,
                    isRequired: true,
                    onChanged: (value) {
                      setState(() {
                        _dates = value;
                        _updateHasChanged(event);
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  EditableTimeRangeField(
                    initialValue: _times,
                    isEditable: _isEditing,
                    isRequired: true,
                    onChanged: (value) {
                      setState(() {
                        _times = value;
                        _updateHasChanged(event);
                      });
                    },
                  ),

                  if (isCreating)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () => _createOrUpdate(null),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Create Company'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}