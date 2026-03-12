
import 'package:crowdpass/models/money.dart';

enum PaymentMethod implements Comparable<PaymentMethod> {
  applePay('Apple Pay'),
  bankTransfer('Bank Transfer'),
  cash('Cash'),
  cashApp('Cash App'),
  check('Check'),
  creditCard('Credit Card'),
  directDeposit('Direct Deposit'),
  googlePay('Google Pay'),
  other('Other'),
  paypal('PayPal'),
  venmo('Venmo'),
  zelle('Zelle');

  final String label;
  const PaymentMethod(this.label);

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (method) => method.name == value,
      orElse: () => PaymentMethod.other,
    );
  }

  @override
  int compareTo(PaymentMethod other) => name.compareTo(other.name);

  @override
  String toString() => name;
}

class Payment implements Comparable<Payment> {
  final Money value;
  final DateTime date;
  final String eventId;
  final String id;
  final bool isCompleted;
  final PaymentMethod method;
  final String payeeId;
  final String payerId;
  final String reference;

  const Payment({
    required this.value,
    required this.date,
    required this.eventId,
    required this.id,
    required this.isCompleted,
    required this.method,
    required this.payeeId,
    required this.payerId,
    required this.reference,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        value: Money.fromJson(json['value'] as Map<String, dynamic>),
        date: DateTime.parse(json['date'] as String),
        eventId: json['eventId'] as String,
        id: json['id'] as String,
        isCompleted: json['isCompleted'] as bool,
        method: PaymentMethod.fromString(json['method'] as String),
        payeeId: json['payeeId'] as String,
        payerId: json['payerId'] as String,
        reference: json['reference'] as String,
      );

  Map<String, dynamic> toJson() => {
        'value': value.toJson(),
        'date': date.toIso8601String(),
        'eventId': eventId,
        'id': id,
        'isCompleted': isCompleted,
        'method': method.name,
        'payeeId': payeeId,
        'payerId': payerId,
        'reference': reference,
      };

  Payment copyWith({
    DateTime? date,
    String? eventId,
    String? id,
    bool? isCompleted,
    PaymentMethod? method,
    String? payeeId,
    String? payerId,
    String? reference,
    Money? value,
  }) {
    return Payment(
      date: date ?? this.date,
      eventId: eventId ?? this.eventId,
      id: id ?? this.id,
      isCompleted: isCompleted ?? this.isCompleted,
      method: method ?? this.method,
      payeeId: payeeId ?? this.payeeId,
      payerId: payerId ?? this.payerId,
      reference: reference ?? this.reference,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Payment &&
          date == other.date &&
          id == other.id &&
          isCompleted == other.isCompleted &&
          method == other.method &&
          payeeId == other.payeeId &&
          payerId == other.payerId &&
          reference == other.reference &&
          value == other.value;

  @override
  int get hashCode => Object.hash(
        date,
        id,
        isCompleted,
        method,
        payeeId,
        payerId,
        reference,
        value,
      );

  @override
  int compareTo(Payment other) => date.compareTo(other.date);

  @override
  String toString() => toJson().toString();
}