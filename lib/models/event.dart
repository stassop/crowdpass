import 'package:flutter/material.dart';

import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/money.dart';
import 'package:crowdpass/models/time_range.dart';

enum EventCategory {
  music('Music', Icons.music_note),
  art('Art', Icons.palette),
  performance('Performance', Icons.theater_comedy),
  film('Film', Icons.movie),
  sports('Sports', Icons.stadium),
  foodDrink('Food & Drink', Icons.restaurant),
  education('Education & Workshops', Icons.school),
  business('Business & Conferences', Icons.business_center),
  nightlife('Nightlife', Icons.nightlife),
  wellness('Wellness', Icons.spa),
  festival('Festivals', Icons.festival),
  family('Family & Kids', Icons.family_restroom),
  other('Other', Icons.category);

  final String label;
  final IconData icon;

  const EventCategory(this.label, this.icon);

  static EventCategory fromString(String value) {
    final normalized = value.trim().toLowerCase();

    return EventCategory.values.firstWhere(
      (category) =>
          category.name.toLowerCase() == normalized ||
          category.label.toLowerCase() == normalized,
      orElse: () => EventCategory.other,
    );
  }
}

enum EventType {
  // MUSIC
  concert('Concert', EventCategory.music),
  liveMusic('Live Music', EventCategory.music),
  djSet('DJ Set', EventCategory.nightlife),

  // FESTIVALS
  musicFestival('Music Festival', EventCategory.festival),
  foodFestival('Food Festival', EventCategory.festival),
  filmFestival('Film Festival', EventCategory.festival),

  // ART
  exhibition('Exhibition', EventCategory.art),
  artFair('Art Fair', EventCategory.art),

  // PERFORMANCE
  theater('Theater', EventCategory.performance),
  comedyShow('Comedy Show', EventCategory.performance),
  dancePerformance('Dance Performance', EventCategory.performance),

  // FILM
  filmScreening('Film Screening', EventCategory.film),

  // SPORTS
  sportsGame('Sports Game', EventCategory.sports),
  tournament('Tournament', EventCategory.sports),

  // FOOD & DRINK
  foodTasting('Food Tasting', EventCategory.foodDrink),
  wineTasting('Wine Tasting', EventCategory.foodDrink),
  diningExperience('Dining Experience', EventCategory.foodDrink),

  // EDUCATION
  workshop('Workshop', EventCategory.education),
  masterclass('Masterclass', EventCategory.education),
  cookingClass('Cooking Class', EventCategory.education),

  // BUSINESS
  conference('Conference', EventCategory.business),
  summit('Summit', EventCategory.business),

  // NIGHTLIFE
  party('Party', EventCategory.nightlife),
  clubNight('Club Night', EventCategory.nightlife),

  // WELLNESS
  yogaClass('Yoga Class', EventCategory.wellness),

  // FAMILY
  kidsShow('Kids Show', EventCategory.family),

  other('Other', EventCategory.other);

  final String label;
  final EventCategory category;

  const EventType(this.label, this.category);

  static EventType fromString(String value) {
    final normalized = value.trim().toLowerCase();

    return EventType.values.firstWhere(
      (type) =>
          type.name.toLowerCase() == normalized ||
          type.label.toLowerCase() == normalized,
      orElse: () => EventType.other,
    );
  }

  static final Map<EventCategory, Set<EventType>> byCategory = {
    for (var category in EventCategory.values)
      category: EventType.values
          .where((type) => type.category == category)
          .toSet()
  };
}

@immutable
class Event implements Comparable<Event> {
  final String companyId;
  final String createdBy;
  final DateTimeRange dates;
  final bool? doorTicketsAvailable;
  final String description;
  final String id;
  final String? imageURL;
  final bool isFree;
  final bool? isEpilepsyFriendly;
  final bool? isFamilyFriendly;
  final bool? isHearingAidCompatible;
  final bool? isLowSensoryFriendly;
  final bool? isPetFriendly;
  final Location location;
  final int? maxTicketsAvailable;
  final bool isOutdoor;
  final bool isWheelchairAccessible;
  final EventType type;
  final DateTimeRange ticketSaleDates;
  final String title;
  final TimeRange times;
  final Money? ticketPrice;

  const Event({
    required this.companyId,
    required this.createdBy,
    required this.dates,
    required this.description,
    required this.id,
    required this.isFree,
    required this.isOutdoor,
    required this.isWheelchairAccessible,
    required this.location,
    required this.ticketSaleDates,
    required this.times,
    required this.title,
    required this.type,
    this.doorTicketsAvailable,
    this.imageURL,
    this.isEpilepsyFriendly,
    this.isFamilyFriendly,
    this.isHearingAidCompatible,
    this.isLowSensoryFriendly,
    this.isPetFriendly,
    this.maxTicketsAvailable,
    this.ticketPrice,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        companyId: json['companyId'] as String,
        createdBy: json['createdBy'] as String,
        dates: DateTimeRange(
          start: DateTime.tryParse(json['dates']['start']) ?? DateTime.now(),
          end: DateTime.tryParse(json['dates']['end']) ?? DateTime.now(),
        ),
        description: json['description'] as String,
        doorTicketsAvailable: json['doorTicketsAvailable'] as bool?,
        id: json['id'] as String,
        imageURL: json['imageURL'] as String?,
        isEpilepsyFriendly: json['isEpilepsyFriendly'] as bool?,
        isFamilyFriendly: json['isFamilyFriendly'] as bool?,
        isFree: json['isFree'] as bool? ?? false,
        isHearingAidCompatible: json['isHearingAidCompatible'] as bool?,
        isLowSensoryFriendly: json['isLowSensoryFriendly'] as bool?,
        isOutdoor: json['isOutdoor'] as bool? ?? false,
        isPetFriendly: json['isPetFriendly'] as bool?,
        isWheelchairAccessible: json['isWheelchairAccessible'] as bool? ?? false,
        location: Location.fromJson(json['location'] as Map<String, dynamic>),
        maxTicketsAvailable: json['maxTicketsAvailable'] as int?,
        ticketPrice: json['ticketPrice'] != null ? Money.fromJson(json['ticketPrice']) : null,
        ticketSaleDates: DateTimeRange(
          start: DateTime.tryParse(json['ticketSaleDates']['start']) ?? DateTime.now(),
          end: DateTime.tryParse(json['ticketSaleDates']['end']) ?? DateTime.now(),
        ),
        times: TimeRange.fromJson(json['times'] as Map<String, dynamic>),
        title: json['title'] as String,
        type: EventType.fromString(json['type'] as String),
      );

  Map<String, dynamic> toJson() => {
        'companyId': companyId,
        'createdBy': createdBy,
        'dates': {
          'end': dates.end.toIso8601String(),
          'start': dates.start.toIso8601String(),
        },
        'description': description,
        'doorTicketsAvailable': doorTicketsAvailable,
        'id': id,
        'imageURL': imageURL,
        'isEpilepsyFriendly': isEpilepsyFriendly,
        'isFamilyFriendly': isFamilyFriendly,
        'isFree': isFree,
        'isHearingAidCompatible': isHearingAidCompatible,
        'isLowSensoryFriendly': isLowSensoryFriendly,
        'isOutdoor': isOutdoor,
        'isPetFriendly': isPetFriendly,
        'isWheelchairAccessible': isWheelchairAccessible,
        'location': location,
        'maxTicketsAvailable': maxTicketsAvailable,
        'ticketPrice': ticketPrice?.toJson(),
        'ticketSaleDates': {
          'end': ticketSaleDates.end.toIso8601String(),
          'start': ticketSaleDates.start.toIso8601String(),
        },
        'times': times.toJson(),
        'title': title,
        'type': type.toString(),
      };

  Event copyWith({
    String? companyId,
    String? createdBy,
    DateTimeRange? dates,
    String? description,
    bool? doorTicketsAvailable,
    String? id,
    String? imageURL,
    bool? isEpilepsyFriendly,
    bool? isFamilyFriendly,
    bool? isFree,
    bool? isHearingAidCompatible,
    bool? isLowSensoryFriendly,
    bool? isOutdoor,
    bool? isPetFriendly,
    bool? isWheelchairAccessible,
    Location? location,
    int? maxTicketsAvailable,
    Money? ticketPrice,
    DateTimeRange? ticketSaleDates,
    TimeRange? times,
    String? title,
    EventType? type,
  }) {
    return Event(
      companyId: companyId ?? this.companyId,
      createdBy: createdBy ?? this.createdBy,
      dates: dates ?? this.dates,
      description: description ?? this.description,
      doorTicketsAvailable: doorTicketsAvailable ?? this.doorTicketsAvailable,
      id: id ?? this.id,
      imageURL: imageURL ?? this.imageURL,
      isEpilepsyFriendly: isEpilepsyFriendly ?? this.isEpilepsyFriendly,
      isFamilyFriendly: isFamilyFriendly ?? this.isFamilyFriendly,
      isFree: isFree ?? this.isFree,
      isHearingAidCompatible: isHearingAidCompatible ?? this.isHearingAidCompatible,
      isLowSensoryFriendly: isLowSensoryFriendly ?? this.isLowSensoryFriendly,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      isPetFriendly: isPetFriendly ?? this.isPetFriendly,
      isWheelchairAccessible: isWheelchairAccessible ?? this.isWheelchairAccessible,
      location: location ?? this.location,
      maxTicketsAvailable: maxTicketsAvailable ?? this.maxTicketsAvailable,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      ticketSaleDates: ticketSaleDates ?? this.ticketSaleDates,
      times: times ?? this.times,
      title: title ?? this.title,
      type: type ?? this.type,
    );
  }

  @override
      bool operator ==(Object other) =>
        identical(this, other) ||
        other is Event &&
          companyId == other.companyId &&
          createdBy == other.createdBy &&
          dates == other.dates &&
          doorTicketsAvailable == other.doorTicketsAvailable &&
          description == other.description &&
          id == other.id &&
          imageURL == other.imageURL &&
          isFree == other.isFree &&
          isEpilepsyFriendly == other.isEpilepsyFriendly &&
          isFamilyFriendly == other.isFamilyFriendly &&
          isHearingAidCompatible == other.isHearingAidCompatible &&
          isLowSensoryFriendly == other.isLowSensoryFriendly &&
          isPetFriendly == other.isPetFriendly &&
          location == other.location &&
          maxTicketsAvailable == other.maxTicketsAvailable &&
          isOutdoor == other.isOutdoor &&
          isWheelchairAccessible == other.isWheelchairAccessible &&
          type == other.type &&
          ticketSaleDates == other.ticketSaleDates &&
          title == other.title &&
          times == other.times &&
          ticketPrice == other.ticketPrice;

  @override
  int get hashCode => Object.hash(
        companyId,
        createdBy,
        dates,
        description,
        doorTicketsAvailable,
        id,
        imageURL,
        isEpilepsyFriendly,
        isFamilyFriendly,
        isFree,
        isHearingAidCompatible,
        isLowSensoryFriendly,
        isOutdoor,
        isPetFriendly,
        isWheelchairAccessible,
        location,
        maxTicketsAvailable,
        ticketSaleDates,
        type,
      );

  @override
  int compareTo(Event other) {
    return dates.start.compareTo(other.dates.start);
  }

  @override
  String toString() => toJson().toString();
}
