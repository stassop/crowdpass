import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:geolocator/geolocator.dart';
// ignore: library_prefixes
import 'package:geocoding/geocoding.dart' as Geocoding;

// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';

import 'package:crowdpass/models/location.dart';

class LocationService {
  static Future<dynamic> _makeOpenStreetMapRequest({
    required String path,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      if (queryParams != null) {
        queryParams = queryParams.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      }

      final language = Intl.getCurrentLocale().split('_').first;

      final request = http.Request(
        'GET',
        Uri.https('nominatim.openstreetmap.org', path, {
          if (queryParams != null) ...queryParams,
          'format': 'json',
          'addressdetails': '1',
          'accept-language': language,
        }),
      )..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'CrowdPass/1.0 (support@crowdpass.app)', // Update to real contact
        });

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Request timed out'),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final contentType = response.headers['content-type'];
        if (contentType != null && contentType.contains('application/json')) {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('error')) {
            throw Exception('Server error: ${data['error']}');
          }
          return data;
        }
      } else {
        throw HttpException('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Request timed out');
    } on SocketException {
      throw Exception('No internet connection');
    } on HttpException catch (error) {
      throw Exception('Request error: $error');
    } on FormatException {
      throw Exception('Bad response format');
    } catch (error) {
      throw Exception('Error: $error');
    }
  }

  /// Parse JSON responses from Nominatim (OpenStreetMap) API:
  /// https://nominatim.org/release-docs/latest/api/Search/
  static Location locationFromOpenStreetMap(Map<String, dynamic> json) {
    // Normalize address: handle both List (e.g. Bijenkorf) and Map (standard search)
    final Map<String, dynamic> addr = {};
    final rawAddr = json['address'];
    if (rawAddr is Map<String, dynamic>) {
      addr.addAll(rawAddr);
    } else if (rawAddr is List) {
      for (var item in rawAddr) {
        addr[item['type']] = item['localname'];
      }
    }

    // Extract Names
    final String fullName = json['display_name'] ?? 'Unknown Location';
    // Short name priority: 'name' field -> first part of display name
    final String shortName = json['name'] ?? json['localname'] ?? (fullName.isNotEmpty ? fullName.split(',').first : 'Unknown Location');

    return Location(
      shortName: shortName,
      fullName: fullName,
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
      // Field Mapping
      address: addr['road'] ?? addr['street'] ?? json['addresstags']?['street'],
      city: addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'],
      state: addr['state'] ?? addr['province'] ?? addr['region'],
      postalCode: addr['postcode'] ?? json['calculated_postcode'],
      countryCode: (json['country_code'] ?? addr['country_code'] as String?)?.toUpperCase(),
      bounds: (json['boundingbox'] as List?)?.map((e) => double.tryParse(e.toString()) ?? 0.0).toList(),
    );
  }

  static Future<Location?> _getGeocodingLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      List<Geocoding.Placemark> placemarks = await Geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return Location(
          address: placemark.street,
          city: placemark.locality,
          state: placemark.administrativeArea,
          countryCode: placemark.isoCountryCode,
          postalCode: placemark.postalCode,
          fullName: [
            // if (placemark.name != null && placemark.name!.isNotEmpty) placemark.name,
            if (placemark.street != null && placemark.street!.isNotEmpty) placemark.street,
            if (placemark.locality != null && placemark.locality!.isNotEmpty) placemark.locality,
            if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) placemark.administrativeArea,
            if (placemark.country != null && placemark.country!.isNotEmpty) placemark.country,
          ].whereType<String>().join(', '),
          shortName: placemark.name ?? placemark.locality ?? 'Unknown Location',
          latitude: latitude,
          longitude: longitude,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Error getting Geocoding location: $e');
    }
  }

  static Future<List<Location>> _searchGeocodingLocation(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final geoLocations = await Geocoding.locationFromAddress(query);
      if (geoLocations.isEmpty) return [];

      final results = await Future.wait(
        geoLocations.map((geoLoc) async {
          return await _getGeocodingLocation(
            latitude: geoLoc.latitude,
            longitude: geoLoc.longitude,
          );
        }),
      );

      // Filter out null results
      return results.whereType<Location>().toList();
    } catch (e) {
      throw Exception('Error searching Geocoding locations: $e');
    }
  }

  static Future<List<Location>> searchLocation(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    // Before making an OSM API call, try using the Geocoding package
    try {
      final locations = await _searchGeocodingLocation(query);
      if (locations.isNotEmpty) {
        return locations;
      }
    } catch (e) {
      // Ignore errors from Geocoding and fallback to OSM
      debugPrint("Error searching Geocoding locations: $e");
    }

    try {
      final data = await _makeOpenStreetMapRequest(
        path: 'search',
        queryParams: {
          'q': query,
          'limit': 10,
        },
      );

      if (data is List) {
        return data.map((e) => locationFromOpenStreetMap(e)).toList();
      } else {
        return [];
      }
    } catch (error) {
      throw Exception('Error searching for location: $error');
    }
  }

  static Future<Location?> getLocationByCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    // Before making an OSM API call, try using the Geocoding package
    try {
      final location = await _getGeocodingLocation(
        latitude: latitude,
        longitude: longitude,
      );
      if (location != null) {
        return location;
      }
    } catch (e) {
      // Ignore errors from Geocoding and fallback to OSM
      debugPrint('Error getting Geocoding location: $e');
    }

    // If Geocoding fails, fallback to OSM reverse geocoding
    try {
      final data = await _makeOpenStreetMapRequest(
        path: 'reverse',
        queryParams: {
          'lat': latitude,
          'lon': longitude,
        },
      );

      if (data is Map && data.containsKey('lat') && data.containsKey('lon')) {
        return locationFromOpenStreetMap(data as Map<String, dynamic>);
      }

      return null;
    } catch (error) {
      throw Exception('Error getting location from coordinates: $error');
    }
  }

  static Future<Location?> getLocationByLocale() async {
    try {
      final countryCode = Intl.getCurrentLocale().split('_').last;
      final data = await _makeOpenStreetMapRequest(
        path: 'search',
        queryParams: {
          'country': countryCode,
          'limit': 1,
        },
      );

      if (data is List && data.isNotEmpty) {
        return locationFromOpenStreetMap(data.first);
      }
      return null;
    } catch (error) {
      throw Exception('Error getting location from country code: $error');
    }
  }

  static Future<Location> getCurrentLocation() async {
    bool locationServiceEnabled;
    LocationPermission permission;

    locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationServiceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final location = await getLocationByCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      // We try to return a Location object even if reverse geocoding fails
      return location ??
          Location(
            latitude: position.latitude,
            longitude: position.longitude,
            shortName: 'Unknown Location',
            fullName: 'Lat: ${position.latitude}, Lon: ${position.longitude}',
          );
    } catch (error) {
      throw Exception('Error getting current location: $error');
    }
  }

  static Future<Location?> getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        return await getLocationByCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
