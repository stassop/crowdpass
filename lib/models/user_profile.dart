import 'package:flutter/foundation.dart';

import 'package:crowdpass/models/country.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String phone;
  final Country country;
  final String? photoURL;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.country,
    this.photoURL,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    try {
      return UserProfile(
        uid: json['uid'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String,
        // This will throw if 'country' is null or missing in the JSON
        country: Country.fromJson(json['country'] as Map<String, dynamic>),
        photoURL: json['photoURL'] as String?,
      );
    } catch (e, st) {
      debugPrint('UserProfile.fromJson failed with data: $json');
      debugPrint('UserProfile.fromJson error: $e');
      debugPrintStack(stackTrace: st);
      throw FormatException('Failed to parse UserProfile from JSON: $e', e);
    }
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'country': country.toJson(),
        if (photoURL != null) 'photoURL': photoURL,
      };

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? phone,
    Country? country,
    String? photoURL,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      country: country ?? this.country,
      photoURL: photoURL ?? this.photoURL,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          displayName == other.displayName &&
          email == other.email &&
          phone == other.phone &&
          country == other.country &&
          photoURL == other.photoURL;

  @override
  int get hashCode =>
      Object.hash(uid, displayName, email, phone, country, photoURL);

  @override
  String toString() {
    return 'UserProfile(uid: $uid, displayName: $displayName, email: $email, phone: $phone, country: $country, photoURL: $photoURL)';
  }
}