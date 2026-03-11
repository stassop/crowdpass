import 'dart:io';

import 'package:intl/intl.dart';

import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

/// A lightweight calendar service that launches the system calendar UI.
class CalendarService {
  /// Launches the native calendar app with a new event prefilled.
  ///
  /// This method opens the calendar app with the event time pre-set.
  /// On Android, it uses an intent URI.
  /// On iOS, it uses a webcal URL to prefill event details.
  static Future<void> addEventToCalendar({
    required String title,
    required String description, // Added description parameter
    required String location,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      if (Platform.isAndroid) {
        final epochStart = startDate.millisecondsSinceEpoch;
        final epochEnd = endDate.millisecondsSinceEpoch;

        final uri = Uri.parse(
          'content://com.android.calendar/time/$epochStart',
        );

        final intent = Uri(
          scheme: 'intent',
          path: uri.toString(),
          queryParameters: <String, String>{
            'title': title,
            'eventLocation': location,
            'description': description, // Add description for Android
          },
          fragment: 'Intent;action=android.intent.action.INSERT;'
              'type=vnd.android.cursor.item/event;'
              'beginTime=$epochStart;'
              'endTime=$epochEnd;'
              'title=$title;'
              'eventLocation=$location;'
              'description=$description;end', // Add description for Android
        );

        if (await canLaunchUrl(intent)) {
          await launchUrl(intent);
        } else {
          throw Exception('Could not launch calendar event on Android');
        }
      } else if (Platform.isIOS) {
        // On iOS, use the webcal protocol to prefill event details.
        // Dates must be formatted to YYYYMMDDTHHMMSSZ (ISO 8601 basic format for iCalendar)
        // Z indicates UTC timezone.
        final DateFormat dateFormat = DateFormat("yyyyMMdd'T'HHmmss'Z'");
        final String formattedStartTime = dateFormat.format(startDate.toUtc());
        final String formattedEndTime = dateFormat.format(endDate.toUtc());

        final Uri url = Uri.parse(
          'webcal://example.com?action=add'
          '&title=${Uri.encodeComponent(title)}'
          '&description=${Uri.encodeComponent(description)}'
          '&location=${Uri.encodeComponent(location)}'
          '&startDate=${formattedStartTime}'
          '&endDate=${formattedEndTime}',
        );

        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        } else {
          throw Exception('Could not launch calendar event on iOS using webcal URL');
        }
      } else {
        throw UnsupportedError('Calendar launching not supported on this platform');
      }
    } catch (error) {
      debugPrint('Error launching calendar event: $error');
      rethrow;
    }
  }
}
