import 'package:flutter/material.dart';

import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/time_range.dart';

enum EventCategory {
  music('Music', Icons.music_note),
  art('Art', Icons.palette),
  performance('Performance', Icons.theater_comedy),
  film('Film', Icons.movie),
  sports('Sports', Icons.sports_soccer),
  foodDrink('Food & Drink', Icons.restaurant),
  education('Education & Workshops', Icons.school),
  business('Business & Conferences', Icons.business_center),
  nightlife('Nightlife', Icons.nightlife),
  wellness('Wellness', Icons.spa),
  festivals('Festivals', Icons.celebration),
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
  musicFestival('Music Festival', EventCategory.festivals),
  foodFestival('Food Festival', EventCategory.festivals),
  filmFestival('Film Festival', EventCategory.festivals),

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
  final DateTime admissionStart;
  final String companyId;
  final String createdBy;
  final DateTimeRange dates;
  final String description;
  final bool isFree;
  final bool isOutdoor;
  final bool isWheelchairAccessible;
  final String id;
  final Location location;
  final String title;
  final EventType type;
  final TimeRange times;
  final bool? isEpilepsyFriendly;
  final bool? isFamilyFriendly;
  final bool? isHearingAidCompatible;
  final bool? isLowSensoryFriendly;
  final bool? isPetFriendly;
  final String? imageURL;

  const Event({
    required this.admissionStart,
    required this.companyId,
    required this.createdBy,
    required this.dates,
    required this.description,
    required this.id,
    required this.isFree,
    required this.isOutdoor,
    required this.isWheelchairAccessible,
    required this.location,
    required this.times,
    required this.title,
    required this.type,
    this.imageURL,
    this.isEpilepsyFriendly,
    this.isFamilyFriendly,
    this.isHearingAidCompatible,
    this.isLowSensoryFriendly,
    this.isPetFriendly,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        admissionStart: DateTime.tryParse(json['admissionStart']) ?? DateTime.now(),
        companyId: json['companyId'] as String,
        createdBy: json['createdBy'] as String,
        dates: DateTimeRange(
          start: DateTime.tryParse(json['dates']['start']) ?? DateTime.now(),
          end: DateTime.tryParse(json['dates']['end']) ?? DateTime.now(),
        ),
        description: json['description'] as String,
        id: json['id'] as String,
        isFree: json['isFree'] as bool? ?? false,
        isOutdoor: json['isOutdoor'] as bool? ?? false,
        isWheelchairAccessible: json['isWheelchairAccessible'] as bool? ?? false,
        location: Location.fromJson(json['location'] as Map<String, dynamic>),
        times: TimeRange.fromJson(json['times'] as Map<String, dynamic>),
        title: json['title'] as String,
        type: EventType.fromString(json['type'] as String),
        imageURL: json['imageURL'] as String?,
        isEpilepsyFriendly: json['isEpilepsyFriendly'] as bool?,
        isFamilyFriendly: json['isFamilyFriendly'] as bool?,
        isHearingAidCompatible: json['isHearingAidCompatible'] as bool?,
        isLowSensoryFriendly: json['isLowSensoryFriendly'] as bool?,
        isPetFriendly: json['isPetFriendly'] as bool?,
      );

  Map<String, dynamic> toJson() => {
        'admissionStart': admissionStart.toIso8601String(),
        'companyId': companyId,
        'createdBy': createdBy,
        'dates': {
          'start': dates.start.toIso8601String(),
          'end': dates.end.toIso8601String(),
        },
        'description': description,
        'id': id,
        'isFree': isFree,
        'isOutdoor': isOutdoor,
        'isWheelchairAccessible': isWheelchairAccessible,
        'location': location,
        'times': times.toJson(),
        'title': title,
        'type': type.toString(),
        if (imageURL != null) 'imageURL': imageURL,
        if (isEpilepsyFriendly != null) 'isEpilepsyFriendly': isEpilepsyFriendly,
        if (isFamilyFriendly != null) 'isFamilyFriendly': isFamilyFriendly,
        if (isHearingAidCompatible != null) 'isHearingAidCompatible': isHearingAidCompatible,
        if (isLowSensoryFriendly != null) 'isLowSensoryFriendly': isLowSensoryFriendly,
        if (isPetFriendly != null) 'isPetFriendly': isPetFriendly,
      };

  Event copyWith({
    DateTime? admissionStart,
    DateTimeRange? dates,
    String? description,
    bool? isFree,
    bool? isOutdoor,
    bool? isWheelchairAccessible,
    Location? location,
    TimeRange? times,
    String? title,
    EventType? type,
    String? imageURL,
    bool? isEpilepsyFriendly,
    bool? isFamilyFriendly,
    bool? isHearingAidCompatible,
    bool? isLowSensoryFriendly,
    bool? isPetFriendly,
  }) {
    return Event(
      // Id, companyId and createdBy can't be changed
      id: id,
      companyId: companyId,
      createdBy: createdBy,
      admissionStart: admissionStart ?? this.admissionStart,
      dates: dates ?? this.dates,
      description: description ?? this.description,
      isFree: isFree ?? this.isFree,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      isWheelchairAccessible: isWheelchairAccessible ?? this.isWheelchairAccessible,
      location: location ?? this.location,
      times: times ?? this.times,
      title: title ?? this.title,
      type: type ?? this.type,
      imageURL: imageURL ?? this.imageURL,
      isEpilepsyFriendly: isEpilepsyFriendly ?? this.isEpilepsyFriendly,
      isFamilyFriendly: isFamilyFriendly ?? this.isFamilyFriendly,
      isHearingAidCompatible: isHearingAidCompatible ?? this.isHearingAidCompatible,
      isLowSensoryFriendly: isLowSensoryFriendly ?? this.isLowSensoryFriendly,
      isPetFriendly: isPetFriendly ?? this.isPetFriendly,
    );
  }

  @override
      bool operator ==(Object other) =>
        identical(this, other) ||
        other is Event &&
          admissionStart == other.admissionStart &&
          companyId == other.companyId &&
          createdBy == other.createdBy &&
          dates == other.dates &&
          description == other.description &&
          id == other.id &&
          isFree == other.isFree &&
          isOutdoor == other.isOutdoor &&
          isWheelchairAccessible == other.isWheelchairAccessible &&
          location == other.location &&
          times == other.times &&
          title == other.title &&
          type == other.type &&
          imageURL == other.imageURL &&
          isEpilepsyFriendly == other.isEpilepsyFriendly &&
          isFamilyFriendly == other.isFamilyFriendly &&
          isHearingAidCompatible == other.isHearingAidCompatible &&
          isLowSensoryFriendly == other.isLowSensoryFriendly &&
          isPetFriendly == other.isPetFriendly;

  @override
  int get hashCode => Object.hash(
        admissionStart,
        companyId,
        createdBy,
        dates,
        description,
        id,
        isFree,
        isOutdoor,
        isWheelchairAccessible,
        location,
        times,
        title,
        type,
        imageURL,
        isEpilepsyFriendly,
        isFamilyFriendly,
        isHearingAidCompatible,
        isLowSensoryFriendly,
        isPetFriendly,
      );

  @override
  int compareTo(Event other) {
    return dates.start.compareTo(other.dates.start);
  }

  @override
  String toString() => toJson().toString();
}
