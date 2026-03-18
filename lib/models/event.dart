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
  final String? createdBy;
  final String? companyId;
  final DateTimeRange? dates;
  final String? description;
  final String? id;
  final Location? location;
  final String? title;
  final EventType? type;
  final TimeRange? times;
  final DateTime? admissionStart;
  final bool? isEpilepsyFriendly;
  final bool? isFamilyFriendly;
  final bool? isFree;
  final bool? isHearingAidCompatible;
  final bool? isLowSensoryFriendly;
  final bool? isOutdoor;
  final bool? isPetFriendly;
  final bool? isWheelchairAccessible;
  final String? imageURL;

  const Event({
    this.admissionStart,
    this.createdBy,
    this.companyId,
    this.dates,
    this.description,
    this.id,
    this.imageURL,
    this.isEpilepsyFriendly,
    this.isFamilyFriendly,
    this.isFree,
    this.isHearingAidCompatible,
    this.isLowSensoryFriendly,
    this.isOutdoor,
    this.isPetFriendly,
    this.isWheelchairAccessible,
    this.location,
    this.times,
    this.title,
    this.type,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        createdBy: json['createdBy'] as String?,
        companyId: json['companyId'] as String?,
        dates: json['dates'] != null && json['dates']['start'] != null && json['dates']['end'] != null
            ? DateTimeRange(
                start: DateTime.tryParse(json['dates']['start']) ?? DateTime.now(),
                end: DateTime.tryParse(json['dates']['end']) ?? DateTime.now(),
              )
            : null,
        description: json['description'] as String?,
        id: json['id'] as String?,
        location: json['location'] != null ? Location.fromJson(json['location'] as Map<String, dynamic>) : null,
        title: json['title'] as String?,
        type: json['type'] != null ? EventType.fromString(json['type'] as String) : null,
        times: json['times'] != null ? TimeRange.fromJson(json['times'] as Map<String, dynamic>) : null,
        admissionStart: json['admissionStart'] != null ? DateTime.tryParse(json['admissionStart']) : null,
        isEpilepsyFriendly: json['isEpilepsyFriendly'] as bool?,
        isFamilyFriendly: json['isFamilyFriendly'] as bool?,
        isFree: json['isFree'] as bool?,
        isHearingAidCompatible: json['isHearingAidCompatible'] as bool?,
        isLowSensoryFriendly: json['isLowSensoryFriendly'] as bool?,
        isOutdoor: json['isOutdoor'] as bool?,
        isPetFriendly: json['isPetFriendly'] as bool?,
        isWheelchairAccessible: json['isWheelchairAccessible'] as bool?,
        imageURL: json['imageURL'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (createdBy != null) 'createdBy': createdBy,
        if (companyId != null) 'companyId': companyId,
        if (dates != null)
          'dates': {
            'start': dates!.start.toIso8601String(),
            'end': dates!.end.toIso8601String(),
          },
        if (description != null) 'description': description,
        if (id != null) 'id': id,
        if (location != null) 'location': location,
        if (title != null) 'title': title,
        if (type != null) 'type': type.toString(),
        if (times != null) 'times': times!.toJson(),
        if (admissionStart != null) 'admissionStart': admissionStart!.toIso8601String(),
        if (isEpilepsyFriendly != null) 'isEpilepsyFriendly': isEpilepsyFriendly,
        if (isFamilyFriendly != null) 'isFamilyFriendly': isFamilyFriendly,
        if (isFree != null) 'isFree': isFree,
        if (isHearingAidCompatible != null) 'isHearingAidCompatible': isHearingAidCompatible,
        if (isLowSensoryFriendly != null) 'isLowSensoryFriendly': isLowSensoryFriendly,
        if (isOutdoor != null) 'isOutdoor': isOutdoor,
        if (isPetFriendly != null) 'isPetFriendly': isPetFriendly,
        if (isWheelchairAccessible != null) 'isWheelchairAccessible': isWheelchairAccessible,
        if (imageURL != null) 'imageURL': imageURL,
      };

  Event copyWith({
    String? createdBy,
    String? companyId,
    DateTimeRange? dates,
    String? description,
    String? id,
    DateTime? admissionStart,
    bool? isEpilepsyFriendly,
    bool? isFamilyFriendly,
    bool? isFree,
    bool? isHearingAidCompatible,
    bool? isLowSensoryFriendly,
    bool? isOutdoor,
    bool? isPetFriendly,
    bool? isWheelchairAccessible,
    String? imageURL,
    Location? location,
    String? title,
    EventType? type,
    TimeRange? times,
  }) {
    return Event(
      createdBy: createdBy ?? this.createdBy,
      companyId: companyId ?? this.companyId,
      id: id ?? this.id,
      location: location ?? this.location,
      title: title ?? this.title,
      type: type ?? this.type,
      times: times ?? this.times,
      dates: dates ?? this.dates,
      description: description ?? this.description,
      admissionStart: admissionStart ?? this.admissionStart,
      isEpilepsyFriendly: isEpilepsyFriendly ?? this.isEpilepsyFriendly,
      isFamilyFriendly: isFamilyFriendly ?? this.isFamilyFriendly,
      isFree: isFree ?? this.isFree,
      isHearingAidCompatible: isHearingAidCompatible ?? this.isHearingAidCompatible,
      isLowSensoryFriendly: isLowSensoryFriendly ?? this.isLowSensoryFriendly,
      isOutdoor: isOutdoor ?? this.isOutdoor,
      isPetFriendly: isPetFriendly ?? this.isPetFriendly,
      isWheelchairAccessible: isWheelchairAccessible ?? this.isWheelchairAccessible,
      imageURL: imageURL ?? this.imageURL,
    );
  }

  @override
      bool operator ==(Object other) =>
        identical(this, other) ||
        other is Event &&
          createdBy == other.createdBy &&
          companyId == other.companyId &&
          dates == other.dates &&
          description == other.description &&
          id == other.id &&
          imageURL == other.imageURL &&
          admissionStart == other.admissionStart &&
          isEpilepsyFriendly == other.isEpilepsyFriendly &&
          isFamilyFriendly == other.isFamilyFriendly &&
          isFree == other.isFree &&
          isHearingAidCompatible == other.isHearingAidCompatible &&
          isLowSensoryFriendly == other.isLowSensoryFriendly &&
          isOutdoor == other.isOutdoor &&
          isPetFriendly == other.isPetFriendly &&
          isWheelchairAccessible == other.isWheelchairAccessible &&
          location == other.location &&
          title == other.title &&
          times == other.times &&
          type == other.type;

  @override
  int get hashCode => Object.hash(
        createdBy,
        companyId,
        dates,
        description,
        id,
        imageURL,
        admissionStart,
        isEpilepsyFriendly,
        isFamilyFriendly,
        isFree,
        isHearingAidCompatible,
        isLowSensoryFriendly,
        isOutdoor,
        isPetFriendly,
        isWheelchairAccessible,
        location,
        title,
        times,
        type,
      );

  @override
  int compareTo(Event other) {
    if (dates == null && other.dates == null) return 0;
    if (dates == null) return -1;
    if (other.dates == null) return 1;
    return dates!.start.compareTo(other.dates!.start);
  }

  @override
  String toString() => toJson().toString();
}
