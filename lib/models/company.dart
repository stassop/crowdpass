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
  final Location? address;
  final String? email;
  final String? id;
  final String? name;
  final Industry? industry;
  final String? phone;
  final String? vatNumber;
  final String? logoURL;
  final String? website;
  final String? ownerId;
  final String? iban;

  const Company({
    this.address,
    this.email,
    this.id,
    this.name,
    this.industry,
    this.phone,
    this.vatNumber,
    this.logoURL,
    this.website,
    this.ownerId,
    this.iban,
  });

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        address: json['address'] != null ? Location.fromJson(json['address'] as Map<String, dynamic>) : null,
        email: json['email'] as String?,
        id: json['id'] as String?,
        logoURL: json['logoURL'] as String?,
        name: json['name'] as String?,
        industry: json['industry'] != null ? Industry.fromString(json['industry'] as String) : null,
        phone: json['phone'] as String?,
        vatNumber: json['vatNumber'] as String?,
        website: json['website'] as String?,
        ownerId: json['ownerId'] as String?,
        iban: json['iban'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (address != null) 'address': address!.toJson(),
        if (email != null) 'email': email,
        if (id != null) 'id': id,
        if (logoURL != null) 'logoURL': logoURL,
        if (name != null) 'name': name,
        if (industry != null) 'industry': industry!.name,
        if (phone != null) 'phone': phone,
        if (vatNumber != null) 'vatNumber': vatNumber,
        if (website != null) 'website': website,
        if (ownerId != null) 'ownerId': ownerId,
        if (iban != null) 'iban': iban,
      };

  Company copyWith({
    Location? address,
    String? email,
    String? id,
    String? logoURL,
    String? name,
    Industry? industry,
    String? phone,
    String? vatNumber,
    String? website,
    String? ownerId,
    String? iban,
  }) {
    return Company(
      address: address ?? this.address,
      email: email ?? this.email,
      id: id ?? this.id,
      logoURL: logoURL ?? this.logoURL,
      name: name ?? this.name,
      industry: industry ?? this.industry,
      phone: phone ?? this.phone,
      vatNumber: vatNumber ?? this.vatNumber,
      website: website ?? this.website,
      ownerId: ownerId ?? this.ownerId,
      iban: iban ?? this.iban,
    );
  }

  @override
    bool operator ==(Object other) =>
      identical(this, other) ||
      other is Company &&
        address == other.address &&
        email == other.email &&
        id == other.id &&
        logoURL == other.logoURL &&
        name == other.name &&
        industry == other.industry &&
        phone == other.phone &&
        vatNumber == other.vatNumber &&
        website == other.website &&
        ownerId == other.ownerId &&
        iban == other.iban;

  @override
  int get hashCode => Object.hash(
        address,
        email,
        id,
        logoURL,
        name,
        industry,
        phone,
        vatNumber,
        website,
        ownerId,
        iban,
      );

  @override
  int compareTo(Company other) {
    if (name == null && other.name == null) return 0;
    if (name == null) return -1;
    if (other.name == null) return 1;
    return name!.compareTo(other.name!);
  }

  @override
  String toString() => toJson().toString();
}