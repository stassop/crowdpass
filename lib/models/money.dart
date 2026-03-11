import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Currency {
  final String code;
  final String name;
  final String symbol;

  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
  });

  // Pre-defined instances (Singletons effectively)
  static const usd = Currency(code: 'USD', name: 'United States Dollar', symbol: '\$');
  static const eur = Currency(code: 'EUR', name: 'Euro', symbol: '€');
  static const gbp = Currency(code: 'GBP', name: 'British Pound Sterling', symbol: '£');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
  
  // Helper to look up by code if needed for JSON
  static Currency fromCode(String code) {
     switch (code.toUpperCase()) {
       case 'EUR': return eur;
       case 'GBP': return gbp;
       default: return usd; // Default or throw error
     }
  }
}

class Money {
  final double amount;
  final Currency currency;

  const Money({required this.amount, required this.currency});

  // Factory for specific currencies creates cleaner call sites
  factory Money.usd(double amount) => Money(amount: amount, currency: Currency.usd);
  factory Money.eur(double amount) => Money(amount: amount, currency: Currency.eur);

  // JSON handling becomes cleaner: "amount" is data, "currency" is a reference
  factory Money.fromJson(Map<String, dynamic> json) {
    return Money(
      amount: (json['amount'] as num).toDouble(),
      currency: Currency.fromCode(json['currency_code'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'currency_code': currency.code,
  };

  String format([Locale? locale]) {
    final effectiveLocale = locale?.toString() ?? Intl.getCurrentLocale();
    return NumberFormat.currency(
      locale: effectiveLocale,
      symbol: currency.symbol,
      name: currency.code,
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