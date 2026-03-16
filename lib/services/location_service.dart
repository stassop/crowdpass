import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
// ignore: library_prefixes
import 'package:geocoding/geocoding.dart' as Geocoding;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:crowdpass/models/location.dart';

class LocationService {
  /// Nominatim Policy: User-Agent is MANDATORY to avoid 403 Forbidden errors.
  static const String _userAgent = 'CrowdPass/1.0 (support@crowdpass.app)';

  static Future<dynamic> _makeOpenStreetMapRequest({
    required String path,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final language = Intl.getCurrentLocale().split('_').first;
      final uri = Uri.https('nominatim.openstreetmap.org', path, {
        if (queryParams != null) ...queryParams.map((k, v) => MapEntry(k, v.toString())),
        'format': 'json',
        'addressdetails': '1',
        'accept-language': language,
      });

      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        throw HttpException('OSM Server Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('OSM Request Failed: $e');
      rethrow;
    }
  }

  static Location locationFromOpenStreetMap(Map<String, dynamic> json) {
    final addr = json['address'] as Map<String, dynamic>? ?? {};
    final String fullName = json['display_name'] ?? '';
    final String shortName = json['name'] ?? 
                             json['localname'] ?? 
                             (fullName.isNotEmpty ? fullName.split(',').first : 'Unknown');

    return Location(
      shortName: shortName,
      fullName: fullName,
      latitude: double.tryParse(json['lat']?.toString() ?? '') ?? 0.0,
      longitude: double.tryParse(json['lon']?.toString() ?? '') ?? 0.0,
      address: addr['road'] ?? addr['house_number'] ?? addr['street'],
      city: addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'],
      state: addr['state'] ?? addr['province'] ?? addr['region'],
      postalCode: addr['postcode'],
      countryCode: (json['country_code'] ?? addr['country_code'] as String?)?.toUpperCase(),
    );
  }

  static Future<List<Location>> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];

    // 1. Try Geocoding package first
    try {
      final List<Geocoding.Location> geoResults = await Geocoding.locationFromAddress(query);
      if (geoResults.isNotEmpty) {
        final List<Location> mappedResults = [];
        for (var geo in geoResults) {
          final loc = await getLocationByCoordinates(
            latitude: geo.latitude, 
            longitude: geo.longitude
          );
          if (loc != null) mappedResults.add(loc);
        }
        if (mappedResults.isNotEmpty) return mappedResults;
      }
    } catch (e) {
      debugPrint('Geocoding search failed: $e');
    }

    // 2. Fallback to OpenStreetMap
    try {
      final data = await _makeOpenStreetMapRequest(
        path: 'search', 
        queryParams: {'q': query, 'limit': 10}
      );
      if (data is List) {
        return data.map((e) => locationFromOpenStreetMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<Location?> getLocationByCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    // 1. Try Geocoding package first
    try {
      final placemarks = await Geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return Location(
          latitude: latitude,
          longitude: longitude,
          shortName: p.name ?? p.locality ?? 'Unknown',
          fullName: [p.street, p.locality, p.postalCode, p.country]
              .where((e) => e != null && e.isNotEmpty)
              .join(', '),
          address: p.street,
          city: p.locality,
          state: p.administrativeArea,
          postalCode: p.postalCode,
          countryCode: p.isoCountryCode,
        );
      }
    } catch (e) {
      debugPrint('Geocoding reverse failed: $e');
    }

    // 2. Fallback to OpenStreetMap
    try {
      final data = await _makeOpenStreetMapRequest(
        path: 'reverse', 
        queryParams: {'lat': latitude, 'lon': longitude}
      );
      if (data is Map<String, dynamic>) return locationFromOpenStreetMap(data);
    } catch (_) {}
    return null;
  }

  static Future<Location> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Location permissions are denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw Exception('Location permissions are permanently denied. Please enable them in settings.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ),
    );

    final location = await getLocationByCoordinates(
      latitude: position.latitude, 
      longitude: position.longitude
    );
    
    return location ?? Location(
      latitude: position.latitude,
      longitude: position.longitude,
      shortName: 'Current Position',
      fullName: 'Lat: ${position.latitude.toStringAsFixed(4)}, Lon: ${position.longitude.toStringAsFixed(4)}',
    );
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
    } catch (e) {
      debugPrint('Error fetching last known location: $e');
      return null;
    }
  }
}