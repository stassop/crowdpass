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
class Company implements Comparable<Company> {
  final Location address;
  final String createdBy;
  final String email;
  final String id;
  final Industry industry;
  final String name;
  final String ownerId;
  final String phone;
  final String vatNumber;
  final String? iban; // Optional properties follow required ones
  final String? logoURL;
  final String? website;

  const Company({
    required this.address,
    required this.createdBy,
    required this.email,
    required this.id,
    required this.industry,
    required this.name,
    required this.ownerId,
    required this.phone,
    required this.vatNumber,
    this.iban,
    this.logoURL,
    this.website,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    try {
      return Company(
        address: Location.fromJson(json['address'] as Map<String, dynamic>),
        createdBy: json['createdBy'] as String,
        email: json['email'] as String,
        id: json['id'] as String,
        industry: Industry.fromString(json['industry'] as String),
        name: json['name'] as String,
        ownerId: json['ownerId'] as String,
        phone: json['phone'] as String,
        vatNumber: json['vatNumber'] as String,
        iban: json['iban'] as String?,
        logoURL: json['logoURL'] as String?,
        website: json['website'] as String?,
      );
    } catch (e, st) {
      debugPrint('Company.fromJson failed with data: $json');
      debugPrint('Company.fromJson error: $e');
      debugPrintStack(stackTrace: st);
      throw FormatException('Failed to parse Company from JSON: $e', e);
    }
  }

  Map<String, dynamic> toJson() => {
        'address': address.toJson(),
        'createdBy': createdBy,
        'email': email,
        'id': id,
        'industry': industry.name,
        'name': name,
        'ownerId': ownerId,
        'phone': phone,
        'vatNumber': vatNumber,
        if (iban != null) 'iban': iban,
        if (logoURL != null) 'logoURL': logoURL,
        if (website != null) 'website': website,
      };

  Company copyWith({
    Location? address,
    String? createdBy,
    String? email,
    String? id,
    Industry? industry,
    String? name,
    String? ownerId,
    String? phone,
    String? vatNumber,
    String? iban,
    String? logoURL,
    String? website,
  }) {
    return Company(
      address: address ?? this.address,
      createdBy: createdBy ?? this.createdBy,
      email: email ?? this.email,
      id: id ?? this.id,
      industry: industry ?? this.industry,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      phone: phone ?? this.phone,
      vatNumber: vatNumber ?? this.vatNumber,
      iban: iban ?? this.iban,
      logoURL: logoURL ?? this.logoURL,
      website: website ?? this.website,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Company &&
          address == other.address &&
          createdBy == other.createdBy &&
          email == other.email &&
          id == other.id &&
          industry == other.industry &&
          name == other.name &&
          ownerId == other.ownerId &&
          phone == other.phone &&
          vatNumber == other.vatNumber &&
          iban == other.iban &&
          logoURL == other.logoURL &&
          website == other.website;

  @override
  int get hashCode => Object.hash(
        address,
        createdBy,
        email,
        id,
        industry,
        name,
        ownerId,
        phone,
        vatNumber,
        iban,
        logoURL,
        website,
      );

  @override
  int compareTo(Company other) {
    return name.compareTo(other.name);
  }

  @override
  String toString() => toJson().toString();
}