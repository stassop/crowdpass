import 'package:flutter/foundation.dart';

import 'package:crowdpass/models/location.dart';
import 'package:flutter/material.dart';

enum Industry {
  arts('Arts', Icons.palette),
  business('Business', Icons.business_center),
  culture('Culture', Icons.museum),
  education('Education', Icons.school),
  entertainment('Entertainment', Icons.movie),
  fashion('Fashion', Icons.checkroom),
  finance('Finance', Icons.attach_money),
  food('Food', Icons.restaurant),
  government('Government', Icons.account_balance),
  health('Health', Icons.health_and_safety),
  hospitality('Hospitality', Icons.hotel),
  individual('Individual', Icons.person),
  nonprofit('Nonprofit', Icons.volunteer_activism),
  religious('Religious', Icons.church),
  sports('Sports', Icons.sports_soccer),
  technology('Technology', Icons.computer),
  wellness('Wellness', Icons.spa),
  other('Other', Icons.category);

  final String label;
  final IconData icon;
  const Industry(this.label, this.icon);

  static Industry fromString(String value) {
    final normalized = value.trim().toLowerCase();
    
    return Industry.values.firstWhere(
      (type) =>
          type.name.toLowerCase() == normalized ||
          type.label.toLowerCase() == normalized,
      orElse: () => Industry.other,
    );
  }

  @override
  String toString() => name;
}

@immutable
class Organizer implements Comparable<Organizer> {
  final Location? address;
  final String? email;
  final String? id;
  final String? companyName;
  final Industry? industry;
  final String? phone;
  final String? vatNumber;
  final String? logoURL;
  final String? website;
  final String? userId;
  final String? iban;

  const Organizer({
    this.address,
    this.email,
    this.id,
    this.companyName,
    this.industry,
    this.phone,
    this.vatNumber,
    this.logoURL,
    this.website,
    this.userId,
    this.iban,
  });

  factory Organizer.fromJson(Map<String, dynamic> json) => Organizer(
        address: json['address'] != null ? Location.fromJson(json['address'] as Map<String, dynamic>) : null,
        email: json['email'] as String?,
        id: json['id'] as String?,
        logoURL: json['logoURL'] as String?,
        companyName: json['companyName'] as String?,
        industry: json['industry'] != null ? Industry.fromString(json['industry'] as String) : null,
        phone: json['phone'] as String?,
        vatNumber: json['vatNumber'] as String?,
        website: json['website'] as String?,
        userId: json['userId'] as String?,
        iban: json['iban'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (address != null) 'address': address!.toJson(),
        if (email != null) 'email': email,
        if (id != null) 'id': id,
        if (logoURL != null) 'logoURL': logoURL,
        if (companyName != null) 'companyName': companyName,
        if (industry != null) 'industry': industry!.name,
        if (phone != null) 'phone': phone,
        if (vatNumber != null) 'vatNumber': vatNumber,
        if (website != null) 'website': website,
        if (userId != null) 'userId': userId,
        if (iban != null) 'iban': iban,
      };

  Organizer copyWith({
    Location? address,
    String? backgroundImageUrl,
    String? email,
    String? id,
    String? logoURL,
    String? companyName,
    Industry? industry,
    String? phone,
    String? vatNumber,
    String? website,
    String? userId,
    String? iban,
  }) {
    return Organizer(
      address: address ?? this.address,
      email: email ?? this.email,
      id: id ?? this.id,
      logoURL: logoURL ?? this.logoURL,
      companyName: companyName ?? this.companyName,
      industry: industry ?? this.industry,
      phone: phone ?? this.phone,
      vatNumber: vatNumber ?? this.vatNumber,
      website: website ?? this.website,
      userId: userId ?? this.userId,
      iban: iban ?? this.iban,
    );
  }

  @override
    bool operator ==(Object other) =>
      identical(this, other) ||
      other is Organizer &&
        address == other.address &&
        email == other.email &&
        id == other.id &&
        logoURL == other.logoURL &&
        companyName == other.companyName &&
        industry == other.industry &&
        phone == other.phone &&
        vatNumber == other.vatNumber &&
        website == other.website &&
        userId == other.userId &&
        iban == other.iban;

  @override
  int get hashCode => Object.hash(
        address,
        email,
        id,
        logoURL,
        companyName,
        industry,
        phone,
        vatNumber,
        website,
        userId,
        iban,
      );

  @override
  int compareTo(Organizer other) {
    if (companyName == null && other.companyName == null) return 0;
    if (companyName == null) return -1;
    if (other.companyName == null) return 1;
    return companyName!.compareTo(other.companyName!);
  }

  @override
  String toString() => toJson().toString();
}