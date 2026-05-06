import 'package:meta/meta.dart';

@immutable
abstract class Unit {
  final String name;
  final String symbol;
  final String isoCode;

  /// The ratio of this unit relative to a "base" unit of the same type.
  /// For example, if meters is base (1.0), then kilometers would be 1000.0.
  final double baseFactor;

  const Unit({
    required this.name,
    required this.symbol,
    required this.isoCode,
    this.baseFactor = 1.0,
  });

  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Unit &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          symbol == other.symbol &&
          isoCode == other.isoCode &&
          baseFactor == other.baseFactor;

  @override
  int get hashCode => Object.hash(name, symbol, isoCode, baseFactor);

  @override
  String toString() => name;
}

@immutable
abstract class UnitValue<T extends Unit> {
  final T unit;
  final double value;

  const UnitValue({required this.unit, required this.value});

  /// Converts the current value to a new unit of the same type [T].
  /// Formula: $Value_{new} = Value_{old} \times \frac{Factor_{old}}{Factor_{new}}$
  UnitValue<T> toUnit(T newUnit);

  Map<String, dynamic> toJson();

  @override
  String toString() => '$value ${unit.symbol}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitValue<T> &&
          runtimeType == other.runtimeType &&
          unit == other.unit &&
          value == other.value;

  @override
  int get hashCode => Object.hash(unit, value);
}
