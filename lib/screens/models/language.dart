class Language implements Comparable<Language> {
  final String isoCode;
  final List<String> locales;
  final String name;
  final String nativeName;

  const Language({
    required this.isoCode,
    required this.locales,
    required this.name,
    required this.nativeName,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      isoCode: json['isoCode'],
      locales: List<String>.from(json['locales']),
      name: json['name'],
      nativeName: json['nativeName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isoCode': isoCode,
      'locales': locales,
      'name': name,
      'nativeName': nativeName,
    };
  }

  @override
  String toString() {
    return this.toJson().toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Language &&
          runtimeType == other.runtimeType &&
          isoCode == other.isoCode;

  @override
  int compareTo(Language other) {
    return isoCode.compareTo(other.isoCode);
  }

  @override
  int get hashCode => isoCode.hashCode;
}
