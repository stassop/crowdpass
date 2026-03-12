class Country implements Comparable<Country> {
  final String name;
  final String nativeName;
  final String isoAlpha2Code;
  final String isoAlpha3Code;
  final List<String> locales;
  final List<String> utcTimeZones;
  final String currencyCode;
  final String phoneCode;

  Country({
    required this.name,
    required this.nativeName,
    required this.isoAlpha2Code,
    required this.isoAlpha3Code,
    required this.locales,
    required this.utcTimeZones,
    required this.currencyCode,
    required this.phoneCode,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      name: json['name'] as String,
      nativeName: json['nativeName'] as String,
      isoAlpha2Code: json['isoAlpha2Code'] as String,
      isoAlpha3Code: json['isoAlpha3Code'] as String,
      locales: List<String>.from(json['locales'] ?? []),
      utcTimeZones: List<String>.from(json['utcTimeZones'] ?? []),
      currencyCode: json['currencyCode'] as String,
      phoneCode: json['phoneCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'nativeName': nativeName,
      'isoAlpha2Code': isoAlpha2Code,
      'isoAlpha3Code': isoAlpha3Code,
      'locales': locales,
      'utcTimeZones': utcTimeZones,
      'currencyCode': currencyCode,
      'phoneCode': phoneCode,
    };
  }

  @override
  String toString() {
    return this.toJson().toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    final Country otherCountry = other as Country;
    return isoAlpha2Code == otherCountry.isoAlpha2Code && phoneCode == otherCountry.phoneCode;
  }
  
  @override
  int get hashCode => Object.hash(isoAlpha2Code, phoneCode);

  @override
  int compareTo(Country other) => name.compareTo(other.name);
}