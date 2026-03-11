import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;

class Location {
  String? city;
  String? countryCode; // ISO 3166-1 alpha-2 code
  String? address;
  double latitude;
  double longitude;
  String? postalCode;
  String? state;
  final String shortName;
  final String fullName;
  List<double>? bounds; // [south, north, west, east] as per OSM/Nominatim format

  Location({
    required this.shortName,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    this.address,
    this.bounds,
    this.city,
    this.countryCode,
    this.postalCode,
    this.state,
  });

  /// Optional: Check if coordinates are valid.
  bool get isValid => latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;

  LatLng get latLng => LatLng(latitude, longitude);

  bool get hasBounds => bounds?.length == 4;

  /// Assumes bounds format: [south, north, west, east]
  LatLngBounds? get latLngBounds => hasBounds
      ? LatLngBounds(
          LatLng(bounds![0], bounds![2]), // SW: south, west
          LatLng(bounds![1], bounds![3]), // NE: north, east
        )
      : null;

  double get suggestedZoom {
    // --- 1. Use Bounds for the most accurate suggestion ---
    if (hasBounds) {
      // Bounds format: [south, north, west, east]
      final south = bounds![0];
      final north = bounds![1];
      final west = bounds![2];
      final east = bounds![3];

      // Calculate the maximum difference (latitude or longitude)
      final latDiff = (north - south).abs();
      final lonDiff = (east - west).abs();
      final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

      // Use a logarithmic-based approach or more detailed ranges for zoom
      if (maxDiff < 0.0001) return 20.0; // Very precise point
      if (maxDiff < 0.0005) return 18.0; // Building/Small area of interest
      if (maxDiff < 0.005) return 16.0; // Street/Block
      if (maxDiff < 0.05) return 14.0; // Neighborhood/Small town
      if (maxDiff < 0.5) return 12.0; // City/Metropolitan area
      if (maxDiff < 5.0) return 8.0;  // State/Region
      return 5.0; // Country or larger
    }

    // --- 2. Infer Zoom based on Address Specificity (when no bounds) ---
    if (address != null && address!.isNotEmpty) {
      return 14.0;
    } else if (postalCode != null && postalCode!.isNotEmpty) {
      return 13.0;
    } else if (city != null && city!.isNotEmpty) {
      return 11.0;
    } else if (state != null && state!.isNotEmpty) {
      return 8.0;
    } else if (countryCode != null && countryCode!.isNotEmpty) {
      return 5.0;
    }

    // --- 3. Default (Fallback) ---
    return 10.0;
  }

  /// Returns the distance to another location in the specified [LengthUnit].
  /// Defaults to Kilometers.
  double distanceTo(Location other, {LengthUnit unit = LengthUnit.Kilometer}) {
    const Distance distance = Distance();
    return distance.as(unit, latLng, other.latLng);
  }

  /// Checks if another location is within a certain distance.
  bool isWithinDistance(Location other, double maxDistance, {LengthUnit unit = LengthUnit.Kilometer}) {
    return distanceTo(other, unit: unit) <= maxDistance;
  }
  
  factory Location.fromJson(Map<String, dynamic> json) {
    try {
      return Location(
        address: json['address'] as String?,
        bounds: (json['bounds'] as List?)?.map((e) => double.parse(e.toString())).toList(),
        city: json['city'] as String?,
        countryCode: json['countryCode'] as String?,
        fullName: json['fullName'] as String,
        shortName: json['shortName'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        postalCode: json['postalCode'] as String?,
        state: json['state'] as String?,
      );
    } catch (e) {
      debugPrint('Error parsing Location from JSON: $e');
      throw FormatException('Invalid Location JSON: $e\nJSON: $json');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'bounds': bounds,
      'city': city,
      'countryCode': countryCode,
      'shortName': shortName,
      'fullName': fullName,
      'latitude': latitude,
      'longitude': longitude,
      'postalCode': postalCode,
      'state': state,
    };
  }

  @override
  String toString() => toJson().toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          runtimeType == other.runtimeType &&
          fullName == other.fullName &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode ^ fullName.hashCode;
}