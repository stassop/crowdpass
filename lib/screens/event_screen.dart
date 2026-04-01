import 'package:crowdpass/models/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/time_range.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/event_provider.dart';

import 'package:crowdpass/widgets/animated_reveal.dart';
import 'package:crowdpass/widgets/animated_app_bar.dart';
import 'package:crowdpass/widgets/editable_address_field.dart';
import 'package:crowdpass/widgets/editable_date_range_field.dart';
import 'package:crowdpass/widgets/editable_event_type_field.dart';
import 'package:crowdpass/widgets/editable_money_field.dart';
import 'package:crowdpass/widgets/editable_number_field.dart';
import 'package:crowdpass/widgets/editable_switch_field.dart';
import 'package:crowdpass/widgets/editable_text_field.dart';
import 'package:crowdpass/widgets/editable_time_range_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';

class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({super.key});

  @override
  ConsumerState<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends ConsumerState<EventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  DateTimeRange? _dates;
  bool? _doorTicketsAvailable;
  String? _description;
  bool? _isEpilepsyFriendly;
  bool? _isFamilyFriendly;
  bool _isFree = false;
  bool? _isHearingAidCompatible;
  bool? _isLowSensoryFriendly;
  bool? _isOutdoor;
  bool? _isPetFriendly;
  bool? _isWheelchairAccessible;
  Location? _location;
  int? _maxTicketsAvailable;
  Money? _ticketPrice;
  DateTimeRange? _ticketSaleDates;
  TimeRange? _times;
  String? _title;
  EventType? _type;
  String? _imageURL;

  // Change tracking
  bool _isEditing = false;
  bool _hasChanged = false;

  void _updateHasChanged(Event? event) {
    _hasChanged =
        _dates != event?.dates ||
        _description != event?.description ||
        _imageURL != event?.imageURL ||
        _isEpilepsyFriendly != event?.isEpilepsyFriendly ||
        _isFamilyFriendly != event?.isFamilyFriendly ||
        _isFree != event?.isFree ||
        _isHearingAidCompatible != event?.isHearingAidCompatible ||
        _isLowSensoryFriendly != event?.isLowSensoryFriendly ||
        _isOutdoor != event?.isOutdoor ||
        _isPetFriendly != event?.isPetFriendly ||
        _isWheelchairAccessible != event?.isWheelchairAccessible ||
        _location != event?.location ||
        _ticketPrice != event?.ticketPrice ||
        _times != event?.times ||
        _title != event?.title ||
        _type != event?.type;
  }

  // Set fields from event
  void _resetFields(Event? event) {
    if (event == null) return;
    _dates = event.dates;
    _description = event.description;
    _doorTicketsAvailable = event.doorTicketsAvailable;
    _imageURL = event.imageURL;
    _isEpilepsyFriendly = event.isEpilepsyFriendly;
    _isFamilyFriendly = event.isFamilyFriendly;
    _isFree = event.isFree;
    _isHearingAidCompatible = event.isHearingAidCompatible;
    _isLowSensoryFriendly = event.isLowSensoryFriendly;
    _isOutdoor = event.isOutdoor;
    _isPetFriendly = event.isPetFriendly;
    _isWheelchairAccessible = event.isWheelchairAccessible;
    _location = event.location;
    _maxTicketsAvailable = event.maxTicketsAvailable;
    _ticketPrice = event.ticketPrice;
    _ticketSaleDates = event.ticketSaleDates;
    _times = event.times;
    _title = event.title;
    _type = event.type;
    _updateHasChanged(event);
  }

  Future<void> _createOrUpdate(String? eventId) async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          eventId == null ? 'Creating event...' : 'Updating event...',
        ),
      ),
    );

    try {
      if (eventId == null) {
        await ref.read(eventNotifier.notifier).createEvent(
          dates: _dates!,
          doorTicketsAvailable: _doorTicketsAvailable,
          description: _description!,
          maxTicketsAvailable: _maxTicketsAvailable,
          ticketSaleDates: _ticketSaleDates!,
          isFree: _isFree,
          isOutdoor: _isOutdoor ?? false,
          isWheelchairAccessible: _isWheelchairAccessible ?? false,
          location: _location!,
          title: _title!,
          type: _type!,
          times: _times!,
          isEpilepsyFriendly: _isEpilepsyFriendly,
          isFamilyFriendly: _isFamilyFriendly,
          isHearingAidCompatible: _isHearingAidCompatible,
          isLowSensoryFriendly: _isLowSensoryFriendly,
          isPetFriendly: _isPetFriendly,
          imagePath: _imageURL,
        );
      } else {
        await ref.read(eventNotifier.notifier).updateEvent(
          dates: _dates!,
          doorTicketsAvailable: _doorTicketsAvailable,
          description: _description!,
          eventId: eventId,
          maxTicketsAvailable: _maxTicketsAvailable,
          ticketSaleDates: _ticketSaleDates!,
          isFree: _isFree,
          isOutdoor: _isOutdoor ?? false,
          isWheelchairAccessible: _isWheelchairAccessible ?? false,
          location: _location!,
          title: _title!,
          type: _type!,
          times: _times!,
          isEpilepsyFriendly: _isEpilepsyFriendly,
          isFamilyFriendly: _isFamilyFriendly,
          isHearingAidCompatible: _isHearingAidCompatible,
          isLowSensoryFriendly: _isLowSensoryFriendly,
          isPetFriendly: _isPetFriendly,
          imagePath: _imageURL,
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
        ErrorDialog.show(
          context,
          title: 'Failed to save event',
          message: e.toString(),
        );
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
          body: Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                AnimatedAppBar(
                  // imageUrl: event.imageUrl, // Pass your image path/url here!
                  title: _title,
                  hintText: 'Event Title',
                  leading: BackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
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
                  onTitleChanged: (value) {
                    setState(() {
                        _title = value;
                        _updateHasChanged(event);
                      });
                    },
                  onPhotoURLChanged: (value) {
                    setState(() {
                      _imageURL = value;
                      _updateHasChanged(event);
                    });
                  },
                  validator: (value) {
                    return (value == null || value.isEmpty)
                        ? 'Event title required'
                        : null;
                  },
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Event Details',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),

                        const SizedBox(height: 16),

                        EditableTextField(
                          initialValue: _description,
                          isEditable: _isEditing,
                          isMultiline: true,
                          minLines: 2,
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
                            return (value == null || value.isEmpty)
                                ? 'Event description required'
                                : null;
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

                        const SizedBox(height: 24),

                        Text(
                          'Tickets',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),

                        const SizedBox(height: 16),

                        AnimatedReveal(
                          isOpen: _isFree == false,
                          child: Column(
                            children: [
                              EditableMoneyField(
                                initialMoney: _ticketPrice,
                                isEditable: _isEditing,
                                isCurrencyEditable: true,
                                decoration: const InputDecoration(
                                  labelText: 'Ticket Price',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _ticketPrice = value;
                                    _updateHasChanged(event);
                                  });
                                },
                              ),

                              const SizedBox(height: 16),

                              EditableDateRangeField(
                                initialValue: _ticketSaleDates,
                                isEditable: _isEditing,
                                isRequired: true,
                                decoration: const InputDecoration(
                                  labelText: 'Ticket Sale Dates',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _ticketSaleDates = value;
                                    _updateHasChanged(event);
                                  });
                                },
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),

                        EditableNumberField(
                          initialValue: _maxTicketsAvailable,
                          isEditable: _isEditing,
                          hasDecimals: false,
                          decoration: const InputDecoration(
                            labelText: 'Max Tickets Available',
                            prefixIcon: Icon(Icons.confirmation_number),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _maxTicketsAvailable = value.toInt();
                              _updateHasChanged(event);
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        EditableSwitchField(
                          labelText: 'Free Event',
                          initialValue: _isFree ?? false,
                          isEditable: _isEditing,
                          leading: const Icon(Icons.money_off),
                          onChanged: (value) {
                            setState(() {
                              _isFree = value;
                              _updateHasChanged(event);
                            });
                          },
                        ),

                        EditableSwitchField(
                          labelText: 'Door Tickets Available',
                          initialValue: _doorTicketsAvailable ?? false,
                          isEditable: _isEditing,
                          leading: const Icon(Icons.door_front_door),
                          onChanged: (value) {
                            setState(() {
                              _doorTicketsAvailable = value;
                              _updateHasChanged(event);
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'Venue Details',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),

                        const SizedBox(height: 16),
                        
                        EditableSwitchField(
                          labelText: 'Outdoor Event',
                          initialValue: _isOutdoor ?? false,
                          isEditable: _isEditing,
                          leading: const Icon(Icons.nature_people),
                          onChanged: (value) {
                            setState(() {
                              _isOutdoor = value;
                              _updateHasChanged(event);
                            });
                          },
                        ),

                        EditableSwitchField(
                          labelText: 'Wheelchair Accessible',
                          initialValue: _isWheelchairAccessible ?? false,
                          isEditable: _isEditing,
                          leading: const Icon(Icons.accessible),
                          onChanged: (value) {
                            setState(() {
                              _isWheelchairAccessible = value;
                              _updateHasChanged(event);
                            });
                          },
                        ),

                        EditableSwitchField(
                          labelText: 'Epilepsy Friendly',
                          initialValue: _isEpilepsyFriendly ?? false,
                          isEditable: _isEditing,
                          leading: const Icon(Icons.flash_off),
                          onChanged: (value) {
                            setState(() {
                              _isEpilepsyFriendly = value;
                              _updateHasChanged(event);
                            });
                          },
                        ),

                        EditableSwitchField(
                          labelText: 'Family Friendly',
                          initialValue: _isFamilyFriendly ?? false,
                          isEditable: _isEditing,
                          leading: const Icon(Icons.family_restroom),
                          onChanged: (value) {
                            setState(() {
                              _isFamilyFriendly = value;
                              _updateHasChanged(event);
                            });
                          },
                        ),

                        EditableSwitchField(
                          labelText: 'Hearing Aid Compatible',
                          initialValue: _isHearingAidCompatible ?? false,
                          isEditable: _isEditing,
                          leading: const Icon(Icons.hearing),
                          onChanged: (value) {
                            setState(() {
                              _isHearingAidCompatible = value;
                              _updateHasChanged(event);
                            });
                          },
                        ),

                        EditableSwitchField(
                          labelText: 'Low Sensory Friendly',
                          initialValue: _isLowSensoryFriendly ?? false,
                          isEditable: _isEditing,
                          leading: const Icon(Icons.volume_off),
                          onChanged: (value) {
                            setState(() {
                              _isLowSensoryFriendly = value;
                              _updateHasChanged(event);
                            });
                          },
                        ),

                        EditableSwitchField(
                          labelText: 'Pet Friendly',
                          initialValue: _isPetFriendly ?? false,
                          isEditable: _isEditing,
                          leading: const Icon(Icons.pets),
                          onChanged: (value) {
                            setState(() {
                              _isPetFriendly = value;
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
                                  : const Text('Create Event'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}