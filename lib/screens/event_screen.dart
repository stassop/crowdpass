import 'package:crowdpass/models/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/time_range.dart';

import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/event_provider.dart';
import 'package:crowdpass/providers/company_provider.dart';

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
  String? _eventId;

  // Form fields
  DateTimeRange? _dates;
  bool _doorTicketsAvailable = false;
  String? _description;
  String? _imageURL;
  bool? _isEpilepsyFriendly;
  bool? _isFamilyFriendly;
  bool _isFree = false;
  bool? _isHearingAidCompatible;
  bool? _isLowSensoryFriendly;
  bool _isOutdoor = false;
  bool? _isPetFriendly;
  bool _isWheelchairAccessible = false;
  Location? _location;
  int? _maxTicketsAvailable;
  Money? _ticketPrice;
  DateTimeRange? _ticketSalesDates;
  TimeRange? _times;
  String? _title;
  EventType? _type;

  // Change tracking
  bool _isEditing = false;

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
    _ticketSalesDates = event.ticketSalesDates;
    _times = event.times;
    _title = event.title;
    _type = event.type;
  }

  Future<void> _createOrUpdate() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all required fields.')),
      );
      return;
    }

    // If the event isn't free, ensure ticket price and sale dates are provided
    if (!_isFree &&
        (_ticketPrice == null ||
            _ticketPrice!.amount <= 0 ||
            _ticketSalesDates == null)) {
      ErrorDialog.show(
        context,
        title: 'Missing Ticket Info',
        message: 'Paid events require a valid ticket price and sales dates.',
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _eventId == null ? 'Creating event...' : 'Updating event...',
        ),
      ),
    );

    try {
      if (_eventId == null) {
        final newEventId = await ref
            .read(eventNotifier.notifier)
            .createEvent(
              dates: _dates!,
              doorTicketsAvailable: _doorTicketsAvailable,
              description: _description!,
              maxTicketsAvailable: _maxTicketsAvailable,
              ticketPrice: _ticketPrice,
              ticketSalesDates: _ticketSalesDates,
              isFree: _isFree,
              isOutdoor: _isOutdoor,
              isWheelchairAccessible: _isWheelchairAccessible,
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
        setState(() {
          _eventId = newEventId;
        });
      } else {
        final event = ref.read(eventProvider(_eventId)).value;
        if (event == null) {
          throw Exception('Event not found');
        }
        await ref
            .read(eventNotifier.notifier)
            .updateEvent(
              updatedEvent: event.copyWith(
                dates: _dates!,
                doorTicketsAvailable: _doorTicketsAvailable,
                description: _description!,
                imageURL: _imageURL,
                isEpilepsyFriendly: _isEpilepsyFriendly,
                isFamilyFriendly: _isFamilyFriendly,
                isFree: _isFree,
                isHearingAidCompatible: _isHearingAidCompatible,
                isLowSensoryFriendly: _isLowSensoryFriendly,
                isOutdoor: _isOutdoor,
                isPetFriendly: _isPetFriendly,
                isWheelchairAccessible: _isWheelchairAccessible,
                location: _location!,
                maxTicketsAvailable: _maxTicketsAvailable,
                ticketPrice: _ticketPrice,
                type: _type!,
                ticketSalesDates: _ticketSalesDates,
                title: _title!,
                times: _times!,
              ),
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

  void _cancelEvent() async {
    // Make sure there's an event to cancel
    if (_eventId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No event to cancel.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Event'),
        content: const Text('Are you sure you want to cancel this event? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, Cancel Event'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(eventNotifier.notifier).cancelEvent(_eventId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event cancelled successfully.')),
          );
          Navigator.of(context).pop(); // Go back after cancellation
        }
      } catch (e) {
        if (mounted) {
          ErrorDialog.show(
            context,
            title: 'Failed to cancel event',
            message: e.toString(),
          );
        }
      }
    }
  }

  void _updateDatesAndTimes({
    DateTimeRange? dates,
    DateTimeRange? ticketSalesDates,
    TimeRange? times,
    bool? doorTicketsAvailable,
  }) {
    dates ??= _dates;
    ticketSalesDates ??= _ticketSalesDates;
    times ??= _times;
    doorTicketsAvailable ??= _doorTicketsAvailable;

    // Don't validate until all required event fields exist.
    if (dates == null || times == null) {
      return;
    }

    final eventStart = DateTime(
      dates.start.year,
      dates.start.month,
      dates.start.day,
      times.start.hour,
      times.start.minute,
    );

    final eventEnd = DateTime(
      dates.end.year,
      dates.end.month,
      dates.end.day,
      times.end.hour,
      times.end.minute,
    );

    // Event must end after it starts.
    if (eventEnd.isBefore(eventStart) || eventEnd.isAtSameMomentAs(eventStart)) {
      if (mounted) {
        ErrorDialog.show(
          context,
          title: 'Schedule Error',
          message: 'Event end must be after the start. '
              'If your event continues after midnight, select a wider date range.',
        );
      }
      return;
    }

    setState(() {
      _times = times;
      _dates = DateTimeRange(start: eventStart, end: eventEnd);
    });

    if (ticketSalesDates == null) {
      return;
    }

    // Normalize sales dates to whole-day bounds first.
    var ticketSalesStart = DateTime(
      ticketSalesDates.start.year,
      ticketSalesDates.start.month,
      ticketSalesDates.start.day,
      0,
      0,
      0,
    );

    var ticketSalesEnd = DateTime(
      ticketSalesDates.end.year,
      ticketSalesDates.end.month,
      ticketSalesDates.end.day,
      23,
      59,
      59,
    );

    // If door tickets are available, 
    // ticket sales can continue until 15 minutes before event end. 
    // Otherwise, sales must end by event start.
    final ticketSalesCutoff = doorTicketsAvailable
        ? eventEnd.subtract(const Duration(minutes: 15))
        : eventStart; 

    // Clamp end: must be <= cutoff (eventEnd-15, and also <= eventStart if no door tickets)
    if (ticketSalesEnd.isAfter(ticketSalesCutoff)) {
      ticketSalesEnd = ticketSalesCutoff;
    }

    // Validate final range
    if (ticketSalesEnd.isBefore(ticketSalesStart) ||
        ticketSalesEnd.isAtSameMomentAs(ticketSalesStart)) {
      if (mounted) {
        ErrorDialog.show(
          context,
          title: 'Schedule Error',
          message:  doorTicketsAvailable
              ? 'Ticket sales must end at least 15 minutes before the event ends, '
                  'and sales cannot start after the event begins.'
              : 'When door tickets are not available, ticket sales must end by the event start time, '
                  'and sales cannot start after the event begins.',
        );
      }
      return;
    }

    setState(() {
      _doorTicketsAvailable = doorTicketsAvailable ?? _doorTicketsAvailable;
      _ticketSalesDates = DateTimeRange(
        start: ticketSalesStart,
        end: ticketSalesEnd,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newEventId = ModalRoute.of(context)?.settings.arguments as String?;
    if (newEventId != _eventId && newEventId != null) {
      _eventId = newEventId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventProvider(_eventId));
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
        // Reset fields when event data changes
        _resetFields(event);

        // Determine whether we're creating a new event 
        final isCreating = _eventId == null || _eventId!.isEmpty || event == null;

        // If the event is null (e.g. invalid ID), show an error message
        final hasChanged = !isCreating && (
          _dates != event.dates ||
          _description != event.description ||
          _doorTicketsAvailable != event.doorTicketsAvailable ||
          _imageURL != event.imageURL ||
          _isEpilepsyFriendly != event.isEpilepsyFriendly ||
          _isFamilyFriendly != event.isFamilyFriendly ||
          _isFree != event.isFree ||
          _isHearingAidCompatible != event.isHearingAidCompatible ||
          _isLowSensoryFriendly != event.isLowSensoryFriendly ||
          _isOutdoor != event.isOutdoor ||
          _isPetFriendly != event.isPetFriendly ||
          _isWheelchairAccessible != event.isWheelchairAccessible ||
          _location != event.location ||
          _maxTicketsAvailable != event.maxTicketsAvailable ||
          _ticketPrice != event.ticketPrice ||
          _ticketSalesDates != event.ticketSalesDates ||
          _times != event.times ||
          _title != event.title ||
          _type != event.type
        );

        // Company is either null, current user's company (if creating), or event's company (if editing)
        final company = isCreating
            ? ref.watch(companyProvider(null)).value
            : ref.watch(companyProvider(event.companyId)).value;

        // If user has no company, show a button that takes them to the company creation screen
        if (isCreating && company == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Create Event'),
              leading: BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'You need a company to create events.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/company/');
                    },
                    child: const Text('Create Company'),
                  ),
                ],
              ),
            ),
          );
        }

        // Auto-enable editing for new companies
        if (isCreating && !_isEditing) {
          _isEditing = true;
        }

        final isOwner = isCreating || event.createdBy == user?.uid;
        final isLoading = ref.watch(eventNotifier).isLoading;

        final eventStarted = event != null &&
             event.dates.start.isBefore(DateTime.now());
        final ticketSalesStarted = event != null &&
            event.ticketSalesDates != null &&
            event.ticketSalesDates!.start.isBefore(DateTime.now());

        final theme = Theme.of(context);

        return Scaffold(
          body: Form(
            key: _formKey,
            child: CustomScrollView(
              slivers: [
                AnimatedAppBar(
                  imageUrl: _imageURL,
                  title: _title,
                  hintText: 'Event Title',
                  leading: BackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  actions: [
                    if (isOwner && !isCreating && !ticketSalesStarted)
                      IconButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                if (_isEditing && hasChanged) {
                                  _createOrUpdate();
                                } else {
                                  setState(() => _isEditing = !_isEditing);
                                }
                              },
                        icon: Icon(
                          _isEditing
                              ? (hasChanged ? Icons.check : Icons.edit_off)
                              : Icons.edit,
                        ),
                      ),
                  ],
                  onTitleChanged: (value) {
                    setState(() {
                      _title = value;
                    });
                  },
                  onPhotoURLChanged: (value) {
                    setState(() {
                      _imageURL = value;
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
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        EditableDateRangeField(
                          initialValue: _dates,
                          isEditable: _isEditing,
                          isRequired: true,
                          onChanged: (value) {
                            _updateDatesAndTimes(dates: value);
                          },
                        ),

                        const SizedBox(height: 16),

                        EditableTimeRangeField(
                          initialValue: _times,
                          isEditable: _isEditing,
                          isRequired: true,
                          onChanged: (value) {
                            _updateDatesAndTimes(times: value);
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
                                isRequired: !_isFree,
                                isCurrencyEditable: true,
                                decoration: const InputDecoration(
                                  labelText: 'Ticket Price',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _ticketPrice = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 16),

                              EditableDateRangeField(
                                initialValue: _ticketSalesDates,
                                isEditable: _isEditing,
                                isRequired: !_isFree,
                                decoration: const InputDecoration(
                                  labelText: 'Ticket Sale Dates',
                                ),
                                onChanged: (value) {
                                  _updateDatesAndTimes(ticketSalesDates: value);
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
                          isRequired: !_isFree,
                          decoration: const InputDecoration(
                            labelText: 'Max Tickets Available',
                            prefixIcon: Icon(Icons.confirmation_number),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _maxTicketsAvailable = value?.toInt();
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        EditableSwitchField(
                          labelText: 'Free Event',
                          initialValue: _isFree,
                          isEditable: _isEditing,
                          isRequired: true,
                          leading: const Icon(Icons.money_off),
                          onChanged: (value) {
                            setState(() {
                              _isFree = value;
                            });
                          },
                        ),

                        EditableSwitchField(
                          labelText: 'Door Tickets Available',
                          initialValue: _doorTicketsAvailable,
                          isEditable: _isEditing,
                          isRequired: !_isFree,
                          leading: const Icon(Icons.door_front_door),
                          onChanged: (value) {
                            _updateDatesAndTimes(doorTicketsAvailable: value);
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
                          initialValue: _isOutdoor,
                          isEditable: _isEditing,
                          isRequired: true,
                          leading: const Icon(Icons.nature_people),
                          onChanged: (value) {
                            setState(() {
                              _isOutdoor = value;
                            });
                          },
                        ),

                        EditableSwitchField(
                          labelText: 'Wheelchair Accessible',
                          initialValue: _isWheelchairAccessible,
                          isEditable: _isEditing,
                          isRequired: true,
                          leading: const Icon(Icons.accessible),
                          onChanged: (value) {
                            setState(() {
                              _isWheelchairAccessible = value;
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
                            });
                          },
                        ),

                        if (isCreating || _isEditing)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: Text(isCreating ? 'Create Event' : 'Save Changes'),
                              onPressed: isLoading
                                  ? null
                                  : () => _createOrUpdate(),
                            ),
                          ),

                        if (!isCreating && !eventStarted)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel Event'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: theme.colorScheme.onError,
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () => _cancelEvent(),
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