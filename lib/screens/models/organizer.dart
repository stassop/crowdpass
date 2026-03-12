import 'package:flutter/foundation.dart';
import 'package:crowdpass/models/location.dart';

@immutable
class Organizer implements Comparable<Organizer> {
  final Location address;
  final String description;
  final String email;
  final String id;
  final String name;
  final String phone;
  final String vatNumber;
  final String? backgroundImageUrl;
  final String? logoUrl;
  final String? website;

  const Organizer({
    required this.address,
    required this.description,
    required this.email,
    required this.id,
    required this.name,
    required this.phone,
    required this.vatNumber,
    this.backgroundImageUrl,
    this.logoUrl,
    this.website,
  });

  factory Organizer.fromJson(Map<String, dynamic> json) => Organizer(
        address: Location.fromJson(json['address'] as Map<String, dynamic>),
        backgroundImageUrl: json['backgroundImageUrl'] as String?,
        description: json['description'] as String,
        email: json['email'] as String,
        id: json['id'] as String,
        logoUrl: json['logoUrl'] as String?,
        name: json['name'] as String,
        phone: json['phone'] as String,
        vatNumber: json['vatNumber'] as String,
        website: json['website'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'address': address.toJson(),
        'backgroundImageUrl': backgroundImageUrl,
        'description': description,
        'email': email,
        'id': id,
        'logoUrl': logoUrl,
        'name': name,
        'phone': phone,
        'vatNumber': vatNumber,
        'website': website,
      };

  Organizer copyWith({
    Location? address,
    String? backgroundImageUrl,
    String? description,
    String? email,
    String? id,
    String? logoUrl,
    String? name,
    String? phone,
    String? vatNumber,
    String? website,
  }) {
    return Organizer(
      address: address ?? this.address,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
      description: description ?? this.description,
      email: email ?? this.email,
      id: id ?? this.id,
      logoUrl: logoUrl ?? this.logoUrl,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vatNumber: vatNumber ?? this.vatNumber,
      website: website ?? this.website,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Organizer &&
          address == other.address &&
          backgroundImageUrl == other.backgroundImageUrl &&
          description == other.description &&
          email == other.email &&
          id == other.id &&
          logoUrl == other.logoUrl &&
          name == other.name &&
          phone == other.phone &&
          vatNumber == other.vatNumber &&
          website == other.website;

  @override
  int get hashCode => Object.hash(
        address,
        backgroundImageUrl,
        description,
        email,
        id,
        logoUrl,
        name,
        phone,
        vatNumber,
        website,
      );

  @override
  int compareTo(Organizer other) => name.compareTo(other.name);

  @override
  String toString() => toJson().toString();
}