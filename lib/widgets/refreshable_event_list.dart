import 'package:flutter/material.dart';

import 'package:crowdpass/models/event.dart';
import 'package:crowdpass/widgets/refreshable_list.dart';
import 'package:intl/intl.dart';

/// A refreshable list of events that shows month and day headers.
class RefreshableEventList extends StatelessWidget {
  final List<Event> events;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool hasMore;
  final bool isLoading;
  final Widget Function(BuildContext context, Event event, int index) itemBuilder;
  final Widget? emptyListWidget;
  final Widget? loadingIndicatorWidget;

  const RefreshableEventList({
    super.key,
    required this.events,
    required this.onRefresh,
    required this.itemBuilder,
    this.onLoadMore,
    this.hasMore = false,
    this.isLoading = false,
    this.emptyListWidget,
    this.loadingIndicatorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<Event>.from(events)
      ..sort((a, b) => a.dates.start.compareTo(b.dates.start));

    final List<_ListEntry> flattened = _buildFlattened(sorted);

    return RefreshableList<Object>(
      onRefresh: onRefresh,
      onLoadMore: onLoadMore,
      hasMore: hasMore,
      isLoading: isLoading,
      items: flattened,
      emptyListWidget: emptyListWidget,
      loadingIndicatorWidget: loadingIndicatorWidget,
      tileBuilder: (ctx, item, index) {
        final entry = item as _ListEntry;
        switch (entry.type) {
          case _EntryType.month:
            return _buildMonthHeader(ctx, entry.date!);
          case _EntryType.day:
            return _buildDayHeader(ctx, entry.date!);
          case _EntryType.event:
            return itemBuilder(ctx, entry.event!, entry.eventIndex!);
        }
      },
    );
  }

  List<_ListEntry> _buildFlattened(List<Event> sortedEvents) {
    final List<_ListEntry> out = [];
    int eventCounter = 0;
    DateTime? lastMonth;
    DateTime? lastDay;

    for (final event in sortedEvents) {
      final start = event.dates.start;
      final monthKey = DateTime(start.year, start.month);
      final dayKey = DateTime(start.year, start.month, start.day);

      if (lastMonth == null || monthKey.year != lastMonth.year || monthKey.month != lastMonth.month) {
        out.add(_ListEntry.month(monthKey));
        lastMonth = monthKey;
        // reset lastDay so day header shows after month header
        lastDay = null;
      }

      if (lastDay == null || dayKey.year != lastDay.year || dayKey.month != lastDay.month || dayKey.day != lastDay.day) {
        out.add(_ListEntry.day(dayKey));
        lastDay = dayKey;
      }

      out.add(_ListEntry.event(event, eventCounter));
      eventCounter += 1;
    }

    return out;
  }

  Widget _buildMonthHeader(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final label = DateFormat.yMMMM(locale).format(date);
    return Container(
      color: theme.colorScheme.primaryContainer,
      child: Text(label, style: theme.textTheme.titleMedium),
    );
  }

  Widget _buildDayHeader(BuildContext context, DateTime date) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final label = DateFormat('EEEE, d MMM yyyy', locale).format(date);
    return Container(
      color: theme.colorScheme.primaryContainer.withAlpha(30),
      child: Text(label, style: theme.textTheme.titleSmall),
    );
  }
}

enum _EntryType { month, day, event }

class _ListEntry {
  final _EntryType type;
  final DateTime? date;
  final Event? event;
  final int? eventIndex;

  const _ListEntry._({required this.type, this.date, this.event, this.eventIndex});

  factory _ListEntry.month(DateTime date) => _ListEntry._(type: _EntryType.month, date: date);
  factory _ListEntry.day(DateTime date) => _ListEntry._(type: _EntryType.day, date: date);
  factory _ListEntry.event(Event event, int index) => _ListEntry._(type: _EntryType.event, event: event, eventIndex: index);
}
