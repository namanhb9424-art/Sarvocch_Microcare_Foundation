/// Helpers for the application's current INR, two-decimal (paise) inputs.
/// Integer minor-unit helpers for INR. Legacy REAL columns remain during the
/// staged database migration and compatibility period.
class CurrencyAmount {
  const CurrencyAmount._();

  static bool hasPaisePrecision(double value) {
    if (!value.isFinite) return false;
    final scaled = value * 100;
    return (scaled - scaled.round()).abs() < 0.000001;
  }

  static double normalize(double value) =>
      double.parse(value.toStringAsFixed(2));

  static int toMinorUnits(double value) {
    if (!hasPaisePrecision(value)) {
      throw ArgumentError('Currency amounts must be in whole paise.');
    }
    return (value * 100).round();
  }

  static double fromMinorUnits(int value) => value / 100;

  static double readStoredValue(
    Map<String, Object?> map,
    String minorUnitsKey,
    String legacyKey,
  ) {
    final minorUnits = map[minorUnitsKey] as num?;
    if (minorUnits != null) return fromMinorUnits(minorUnits.toInt());
    return (map[legacyKey] as num?)?.toDouble() ?? 0;
  }

  static int readStoredMinorUnits(
    Map<String, Object?> map,
    String minorUnitsKey,
    String legacyKey,
  ) {
    final minorUnits = map[minorUnitsKey] as num?;
    if (minorUnits != null) return minorUnits.toInt();
    final legacyValue = map[legacyKey] as num?;
    if (legacyValue == null) return 0;
    return toMinorUnits(legacyValue.toDouble());
  }
}
