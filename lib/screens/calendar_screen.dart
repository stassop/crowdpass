import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/event.dart';

import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/providers/calendar_provider.dart';

import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/calendar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() =>
      _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProvider(null));

    return companyAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.maybePop(context)),
          title: const Text('Error'),
        ),
        body: Center(child: Text('Error: $e')),
      ),
      data: (company) {
        if (company == null) {
          return Scaffold(
            appBar: AppBar(
              leading: BackButton(onPressed: () => Navigator.maybePop(context)),
              title: const Text('Company Not Found'),
            ),
            body: const Center(
              child: Text('Event company not found.'),
            ),
          );
        }

        final state = ref.watch(calendarProvider(company.id));
        final notifier = ref.read(calendarProvider(company.id).notifier);

        // Show error dialog if error exists
        if (state.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ErrorDialog.show(
              context,
              title: 'Error loading filters',
              message: state.error.toString(),
            );
          });
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('My Events'),
          ),
          body: Calendar(
            events: state.events,
            onEventSelected: (event) {
              Navigator.pushNamed(context, '/event/', arguments: event.id);
            },
            onChanged: (value) {
              notifier.setFilters(state.filters.copyWith(dates: value));
            },
          ),
        );
      },
    );
  }
}
