import 'dart:collection';
import 'package:meta/meta.dart';
import 'package:latlong2/latlong.dart' show LengthUnit;
import 'package:crowdpass/models/unit_value.dart' show Unit;

@immutable
class DistanceUnit extends Unit {
  /// The corresponding latlong2 LengthUnit
  final LengthUnit lengthUnit;

  /// Private cache for the units set to prevent re-creation on every access
  static final Set<DistanceUnit> _units = {
    meter,
    kilometer,
    mile,
  };

  const DistanceUnit({
    required super.name,
    required super.symbol,
    required super.isoCode,
    super.baseFactor = 1.0,
    required this.lengthUnit,
  });

  // Predefined compile-time constants
  static const DistanceUnit meter = DistanceUnit(
    name: 'Meter',
    symbol: 'm',
    isoCode: 'MTR',
    baseFactor: 1.0,
    lengthUnit: LengthUnit.Meter,
  );

  static const DistanceUnit kilometer = DistanceUnit(
    name: 'Kilometer',
    symbol: 'km',
    isoCode: 'KMT',
    baseFactor: 1000.0,
    lengthUnit: LengthUnit.Kilometer,
  );

  static const DistanceUnit mile = DistanceUnit(
    name: 'Mile',
    symbol: 'mi',
    isoCode: 'SMI',
    baseFactor: 1609.344,
    lengthUnit: LengthUnit.Mile,
  );

  @override
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'symbol': symbol,
      'isoCode': isoCode,
      'baseFactor': baseFactor,
      'lengthUnitScaleFactor': lengthUnit.scaleFactor,
    };
  }

  /// Returns an unmodifiable Set of all available DistanceUnits.
  static Set<DistanceUnit> get units => UnmodifiableSetView(_units);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && // Reuses Unit class equality rules
          other is DistanceUnit &&
          runtimeType == other.runtimeType &&
          lengthUnit == other.lengthUnit;

  @override
  int get hashCode => Object.hash(super.hashCode, lengthUnit);
}