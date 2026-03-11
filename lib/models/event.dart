import 'package:flutter/material.dart';

import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/models/time_range.dart';

enum EventCategory {
  music('Music'),
  art('Art'),
  sports('Sports'),
  food('Food'),
  education('Education'),
  networking('Networking'),
  social('Social'),
  other('Other');

  final String label;

  /// Get event category from a string label (case-insensitive)
  static EventCategory? fromString(String value) {
    return EventCategory.values.firstWhere(
      (category) => category.name == value.trim().toLowerCase(),
      orElse: () => other,
    );
  }

  const EventCategory(this.label);
}

enum EventType {
  concert('Concert', EventCategory.music),
  festival('Festival', EventCategory.music),
  exhibition('Exhibition', EventCategory.art),
  workshop('Workshop', EventCategory.education),
  meetup('Meetup', EventCategory.networking),
  party('Party', EventCategory.social),
  sportsGame('Sports Game', EventCategory.sports),
  foodTasting('Food Tasting', EventCategory.food),
  other('Other', EventCategory.other);

  final String label;
  final EventCategory category;

  const EventType(this.label, this.category);

  static EventType? fromString(String value) {
    return EventType.values.firstWhere(
      (type) => type.name == value.trim().toLowerCase(),
      orElse: () => other,
    );
  }

  static Map<EventCategory, Set<EventType>> get byCategory {
    final Map<EventCategory, Set<EventType>> map = {};
    for (var type in EventType.values) {
      map.putIfAbsent(type.category, () => {}).add(type);
    }
    return map;
  }
}

@immutable
class Event implements Comparable<Event> {
  final DateTimeRange dates;
  final String description;
  final bool isFamilyFriendly;
  final bool isFree;
  final bool isWheelChairAccessible;
  final String? imageUrl;
  final Location location;
  final String name;
  final EventType? type;
  final TimeRange times;
  final String id;

  const Event({
    required this.dates,
    required this.description,
    this.isFamilyFriendly = false,
    this.isFree = false,
    this.isWheelChairAccessible = false,
    this.imageUrl,
    required this.location,
    required this.name,
    required this.type,
    required this.times,
    required this.id,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        dates: DateTimeRange(
          start: DateTime.parse(json['dates']['start'] as String),
          end: DateTime.parse(json['dates']['end'] as String),
        ),
        description: json['description'] as String,
        isFamilyFriendly: json['isFamilyFriendly'] ?? false,
        isFree: json['isFree'] ?? false,
        isWheelChairAccessible: json['isWheelChairAccessible'] ?? false,
        imageUrl: json['imageUrl'],
        location: Location.fromJson(json['location'] as Map<String, dynamic>),
        name: json['name'] as String,
        type: EventType.fromString(json['type'] as String? ?? ''),
        times: TimeRange.fromJson(json['times'] as Map<String, dynamic>),
        id: json['id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'dates': {
          'start': dates.start.toIso8601String(),
          'end': dates.end.toIso8601String(),
        },
        'description': description,
        'isFamilyFriendly': isFamilyFriendly,
        'isFree': isFree,
        'isWheelChairAccessible': isWheelChairAccessible,
        'imageUrl': imageUrl,
        'location': location,
        'name': name,
        'type': type?.name,
        'times': times.toJson(),
        'id': id,
      };

  Event copyWith({
    DateTimeRange? dates,
    String? description,
    bool? isFamilyFriendly,
    bool? isFree,
    bool? isWheelChairAccessible,
    String? imageUrl,
    Location? location,
    String? name,
    EventType? type,
    TimeRange? times,
    String? id,
  }) {
    return Event(
      dates: dates ?? this.dates,
      description: description ?? this.description,
      isFamilyFriendly: isFamilyFriendly ?? this.isFamilyFriendly,
      isFree: isFree ?? this.isFree,
      isWheelChairAccessible: isWheelChairAccessible ?? this.isWheelChairAccessible,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      name: name ?? this.name,
      type: type ?? this.type,
      times: times ?? this.times,
      id: id ?? this.id,
    );
  }

  @override
    bool operator ==(Object other) =>
      identical(this, other) ||
      other is Event &&
        dates == other.dates &&
        description == other.description &&
        isFamilyFriendly == other.isFamilyFriendly &&
        isFree == other.isFree &&
        isWheelChairAccessible == other.isWheelChairAccessible &&
        imageUrl == other.imageUrl &&
        location == other.location &&
        name == other.name &&
        type == other.type &&
        times == other.times &&
        id == other.id;

  @override
  int get hashCode => Object.hash(
        dates,
        description,
        isFamilyFriendly,
        isFree,
        isWheelChairAccessible,
        imageUrl,
        location,
        name,
        type,
        times,
        id,
      );

  @override
    int compareTo(Event other) => dates.start.compareTo(other.dates.start);

  @override
  String toString() => toJson().toString();
}
