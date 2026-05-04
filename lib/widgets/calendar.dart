import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:crowdpass/models/event.dart'; // Ensure your Event model has a 'dates' field with 'start' and 'end'

class Calendar extends StatefulWidget {
  final List<Event> events;
  final DateTime? startDate;
  final ValueChanged<DateTimeRange>? onChanged;
  final ValueChanged<Event>? onEventSelected;

  const Calendar({
    super.key,
    this.events = const [],
    this.startDate,
    this.onChanged,
    this.onEventSelected,
  });

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.startDate ?? DateTime.now();
    // Schedule callback after the first frame to avoid building during layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyDatesChanged());
  }

  void _notifyDatesChanged() {
    final range = DateTimeRange(
      start: DateTime(_currentDate.year, _currentDate.month, 1),
      end: DateTime(_currentDate.year, _currentDate.month + 1, 0, 23, 59, 59),
    );
    widget.onChanged?.call(range);
  }

  // Pre-groups events by date string for O(1) lookup in the grid
  Map<DateTime, List<Event>> _getEventMap() {
    final map = <DateTime, List<Event>>{};
    for (var event in widget.events) {
      final key = DateTime(event.dates.start.year, event.dates.start.month, event.dates.start.day);
      map.putIfAbsent(key, () => []).add(event);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final eventMap = _getEventMap();
    
    final today = DateTime.now();
    final firstDayOfMonth = DateTime(_currentDate.year, _currentDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_currentDate.year, _currentDate.month);
    
    // Calendar Generation Logic
    final days = <DateTime>[];
    final firstWeekday = firstDayOfMonth.weekday; // Monday = 1, Sunday = 7

    // Fill previous month's trailing days
    for (int i = 1; i < firstWeekday; i++) {
      days.add(firstDayOfMonth.subtract(Duration(days: firstWeekday - i)));
    }

    // Current month days
    for (int i = 0; i < daysInMonth; i++) {
      days.add(DateTime(_currentDate.year, _currentDate.month, i + 1));
    }

    // Fill next month's leading days to complete the 7-column grid
    while (days.length % 7 != 0) {
      days.add(days.last.add(const Duration(days: 1)));
    }

    return Column(
      children: [
        _buildHeader(theme, locale),
        const SizedBox(height: 16),
        _buildWeekdayLabels(theme, locale),
        const SizedBox(height: 8),
        _buildCalendarGrid(days, eventMap, theme, today),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, String locale) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1));
            _notifyDatesChanged();
          },
        ),
        Text(
          DateFormat.yMMMM(locale).format(_currentDate),
          style: theme.textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1));
            _notifyDatesChanged();
          },
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(ThemeData theme, String locale) {
    final weekdayFormat = DateFormat.E(locale);
    return Row(
      children: List.generate(7, (index) {
        // Jan 6 2020 was a Monday
        final weekday = weekdayFormat.format(DateTime(2020, 1, 6 + index));
        return Expanded(
          child: Center(
            child: Text(weekday, style: theme.textTheme.labelLarge),
          ),
        );
      }),
    );
  }

  Widget _buildCalendarGrid(List<DateTime> days, Map<DateTime, List<Event>> eventMap, ThemeData theme, DateTime today) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final isToday = DateUtils.isSameDay(day, today);
        final isCurrentMonth = day.month == _currentDate.month;
        final events = eventMap[DateTime(day.year, day.month, day.day)] ?? [];

        return InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CalendarDay(
                  date: day,
                  events: events,
                  onEventSelected: widget.onEventSelected,
                ),
              ),
            );
          },
          child: Container(
            decoration: isToday 
              ? BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle) 
              : null,
            child: Center(
              child: Badge.count(
                count: events.length,
                isLabelVisible: events.isNotEmpty,
                backgroundColor: theme.colorScheme.primary,
                offset: const Offset(12, -12),
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isToday 
                        ? theme.colorScheme.onPrimaryContainer
                        : isCurrentMonth ? null : theme.disabledColor,
                    fontWeight: isToday ? FontWeight.bold : null,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CalendarDay extends StatelessWidget {
  final DateTime date;
  final List<Event> events;
  final ValueChanged<Event>? onEventSelected;

  const CalendarDay({
    super.key,
    required this.date,
    required this.events,
    this.onEventSelected,
  });

  static const double hourHeight = 64.0;
  static const double leftGutterWidth = 60.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final sortedEvents = List.of(events)
      ..sort((a, b) => a.dates.start.compareTo(b.dates.start));

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMMd(locale).format(date)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Determine width per event if there are multiple events in the day
            final availableWidth = constraints.maxWidth - leftGutterWidth - 16;
            final eventWidth = sortedEvents.isNotEmpty
                ? (availableWidth / sortedEvents.length) - 2
                : availableWidth;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                height: 24 * hourHeight,
                child: Stack(
                  children: [
                    _buildTimeGrid(context, theme),
                    ...sortedEvents.asMap().entries.map((entry) => _buildEventTile(
                        context, theme, entry.value, entry.key, eventWidth)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeGrid(BuildContext context, ThemeData theme) {
    return Column(
      children: List.generate(24, (hour) {
        return SizedBox(
          height: hourHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // <--- Add this to align line to the exact hour start
            children: [
              SizedBox(
                width: leftGutterWidth,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    TimeOfDay(hour: hour, minute: 0).format(context),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.hintColor,
                      height: 1, // Removes built-in text leading so it sits perfectly flush with the divider
                    ),
                  ),
                ),
              ),
              const Expanded(child: Divider(height: 1)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildEventTile(
      BuildContext context, ThemeData theme, Event event, int index, double eventWidth) {
    // If the event starts before the current date, it spans from midnight
    final isStartDay = DateUtils.isSameDay(event.dates.start, date);
    final startHourDecimal = isStartDay
        ? event.times.start.hour + (event.times.start.minute / 60.0)
        : 0.0;

    // If the event ends after the current date, it spans until midnight
    final isEndDay = DateUtils.isSameDay(event.dates.end, date);
    final endHourDecimal = isEndDay
        ? event.times.end.hour + (event.times.end.minute / 60.0)
        : 24.0;

    final top = startHourDecimal * hourHeight;
    final height = ((endHourDecimal - startHourDecimal).clamp(0.5, 24.0)) * hourHeight;

    return Positioned(
      top: top,
      left: leftGutterWidth + 8 + (index * (eventWidth + 2)), // 2px space between events
      width: eventWidth,
      child: GestureDetector(
        onTap: () => onEventSelected?.call(event),
        child: Container(
          height: height,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: null, // Title will wrap instead of getting clipped
              ),
              if (height > 40)
                Flexible(
                  child: Text(
                    event.description,
                    style: theme.textTheme.bodySmall,
                    maxLines: height > 80 ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}