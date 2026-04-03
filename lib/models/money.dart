import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Currency {
  final String isoCode; // Renamed from 'code'
  final String name;
  final String symbol;
  final String nativeName;
  final List<String> countries;

  const Currency({
    required this.isoCode, // Updated parameter name
    required this.name,
    required this.symbol,
    required this.nativeName,
    required this.countries,
  });

  // Pre-defined instances (Singletons effectively)
  static const usd = Currency(
    isoCode: 'USD', // Updated property name
    name: 'United States Dollar',
    symbol: '\$',
    nativeName: 'Dollar',
    countries: ["US", "AS", "EC", "SV", "GU", "IO", "MH", "FM", "MP", "PW", "PA", "PR", "TL", "TC", "VG", "VI"],
  );
  static const eur = Currency(
    isoCode: 'EUR', // Updated property name
    name: 'Euro',
    symbol: '€',
    nativeName: 'Euro',
    countries: ["AD", "AT", "BE", "CY", "EE", "FI", "FR", "DE", "GR", "IE", "IT", "LV", "LT", "LU", "MT", "MC", "NL", "PT", "SM", "SK", "SI", "ES", "VA", "ME"],
  );
  static const gbp = Currency(
    isoCode: 'GBP', // Updated property name
    name: 'British Pound Sterling',
    symbol: '£',
    nativeName: 'Pound',
    countries: ["GB", "IM", "JE", "GG", "GS", "FK", "SH"],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency && runtimeType == other.runtimeType && isoCode == other.isoCode; // Updated comparison

  @override
  int get hashCode => isoCode.hashCode; // Updated hashCode

  factory Currency.fromJson(Map<String, dynamic> json) {
    try {
      return Currency(
        isoCode: json['isoCode'] as String, // Updated key
        name: json['name'] as String,
        symbol: json['symbol'] as String,
        nativeName: json['nativeName'] as String,
        // Fixed: Using unmodifiable list to maintain strict immutability
        countries: List<String>.unmodifiable(json['countries'] as List),
      );
    } catch (e, st) {
      debugPrint('Currency.fromJson failed with data: $json');
      debugPrint('Currency.fromJson error: $e');
      debugPrintStack(stackTrace: st);
      throw FormatException('Failed to parse Currency from JSON: $e', e);
    }
  }

  Map<String, dynamic> toJson() => {
    'isoCode': isoCode, // Updated key
    'name': name,
    'symbol': symbol,
    'nativeName': nativeName,
    'countries': countries,
  };
}

class Money {
  final double amount;
  final Currency currency;

  const Money({required this.amount, required this.currency});

  // Factory for specific currencies creates cleaner call sites
  factory Money.usd(double amount) => Money(amount: amount, currency: Currency.usd);
  factory Money.eur(double amount) => Money(amount: amount, currency: Currency.eur);
  factory Money.gbp(double amount) => Money(amount: amount, currency: Currency.gbp);

  // JSON handling becomes cleaner: "amount" is data, "currency" is a reference
  factory Money.fromJson(Map<String, dynamic> json) {
    // Fixed: Corrected parenthesis formatting
    return Money(
      amount: (json['amount'] as num).toDouble(),
      currency: Currency.fromJson(json['currency'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currency': currency.toJson(), // Assuming Currency has a toJson method
  };

  String format([Locale? locale]) {
    // Fixed: Used toLanguageTag() for proper intl BCP47 formatting compatibility
    final effectiveLocale = locale?.toLanguageTag() ?? Intl.getCurrentLocale();
    return NumberFormat.currency(
      locale: effectiveLocale,
      symbol: currency.symbol,
      name: currency.isoCode, // Updated property name
    ).format(amount);
  }
  
  // You can now easily add math logic
  Money operator +(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Cannot add different currencies');
    }
    return Money(amount: amount + other.amount, currency: currency);
  }
  
  @override
  String toString() => format();
}