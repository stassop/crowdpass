import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import 'package:crowdpass/models/unit_value.dart';

class Currency extends Unit {
  final String nativeName;
  final List<String> countries;

  const Currency({
    required super.isoCode,
    required super.name,
    required super.symbol,
    required this.nativeName,
    required this.countries,
    super.baseFactor = 1.0, 
  });

  // Pre-defined instances
  static const usd = Currency(
    isoCode: 'USD',
    name: 'United States Dollar',
    symbol: '\$',
    nativeName: 'Dollar',
    countries: ["US", "AS", "EC", "SV", "GU", "IO", "MH", "FM", "MP", "PW", "PA", "PR", "TL", "TC", "VG", "VI"],
  );
  static const eur = Currency(
    isoCode: 'EUR',
    name: 'Euro',
    symbol: '€',
    nativeName: 'Euro',
    countries: ["AD", "AT", "BE", "CY", "EE", "FI", "FR", "DE", "GR", "IE", "IT", "LV", "LT", "LU", "MT", "MC", "NL", "PT", "SM", "SK", "SI", "ES", "VA", "ME"],
  );
  static const gbp = Currency(
    isoCode: 'GBP',
    name: 'British Pound Sterling',
    symbol: '£',
    nativeName: 'Pound',
    countries: ["GB", "IM", "JE", "GG", "GS", "FK", "SH"],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && 
      other is Currency &&
      nativeName == other.nativeName &&
      const ListEquality().equals(countries, other.countries);

  @override
  int get hashCode => Object.hash(super.hashCode, nativeName, const ListEquality().hash(countries));

  factory Currency.fromJson(Map<String, dynamic> json) {
    try {
      return Currency(
        isoCode: json['isoCode'] as String,
        name: json['name'] as String,
        symbol: json['symbol'] as String,
        nativeName: json['nativeName'] as String,
        countries: List<String>.unmodifiable(json['countries'] as List),
        baseFactor: (json['baseFactor'] as num?)?.toDouble() ?? 1.0,
      );
    } catch (e, st) {
      debugPrint('Currency.fromJson failed with data: $json');
      debugPrint('Currency.fromJson error: $e');
      debugPrintStack(stackTrace: st);
      throw FormatException('Failed to parse Currency from JSON: $e', e);
    }
  }

  @override
  Map<String, dynamic> toJson() => {
    'isoCode': isoCode,
    'name': name,
    'symbol': symbol,
    'nativeName': nativeName,
    'countries': countries,
    'baseFactor': baseFactor,
  };
}

class Money extends UnitValue<Currency> {
  const Money({required double amount, required Currency currency})
      : super(value: amount, unit: currency);

  // Convenience getters to maintain compatibility with existing call sites
  double get amount => value;
  Currency get currency => unit;

  // Factory for specific currencies
  factory Money.usd(double amount) => Money(amount: amount, currency: Currency.usd);
  factory Money.eur(double amount) => Money(amount: amount, currency: Currency.eur);
  factory Money.gbp(double amount) => Money(amount: amount, currency: Currency.gbp);

  factory Money.fromJson(Map<String, dynamic> json) {
    return Money(
      amount: (json['amount'] as num).toDouble(),
      currency: Currency.fromJson(json['currency'] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currency': currency.toJson(), 
  };

  /// Satisfies the abstract [UnitValue] requirement.
  /// Uses [baseFactor] (acting as an exchange rate relative to a base fiat) 
  /// to convert between currencies.
  @override
  Money toUnit(Currency newUnit) {
    final convertedValue = value * (unit.baseFactor / newUnit.baseFactor);
    return Money(amount: convertedValue, currency: newUnit);
  }

  String format([Locale? locale]) {
    final effectiveLocale = locale?.toLanguageTag() ?? Intl.getCurrentLocale();
    return NumberFormat.currency(
      locale: effectiveLocale,
      symbol: currency.symbol,
      name: currency.isoCode, 
    ).format(amount);
  }
  
  Money operator +(Money other) {
    if (other.currency != currency) {
      // Alternatively, you could auto-convert here using `toUnit` 
      // if your baseFactors are populated with live exchange rates.
      throw ArgumentError('Cannot add different currencies directly.');
    }
    return Money(amount: amount + other.amount, currency: currency);
  }
  
  @override
  String toString() => format();
}