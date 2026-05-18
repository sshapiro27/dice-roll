import 'dart:math';

/// The curated set of supported dice.
enum DieType { d4, d6, d8, d10, d12, d20, d100 }

extension DieTypeInfo on DieType {
  int get sides => switch (this) {
        DieType.d4 => 4,
        DieType.d6 => 6,
        DieType.d8 => 8,
        DieType.d10 => 10,
        DieType.d12 => 12,
        DieType.d20 => 20,
        DieType.d100 => 100,
      };

  String get label => 'd$sides';

  /// Number of polygon edges to draw for the procedural die shape.
  /// (Placeholder geometry until rendered stone sprites replace it.)
  int get visualSides => switch (this) {
        DieType.d4 => 3,
        DieType.d100 => 12,
        _ => sides.clamp(3, 12),
      };
}

/// Outcome of a single roll. For d100 the [tens] and [units] components are
/// the two underlying d10 results (classic percentile).
class RollResult {
  RollResult({
    required this.die,
    required this.value,
    this.tens,
    this.units,
  });

  final DieType die;
  final int value;
  final int? tens;
  final int? units;

  bool get isPercentile => die == DieType.d100;
}

class Dice {
  Dice([Random? rng]) : _rng = rng ?? Random.secure();

  final Random _rng;

  RollResult roll(DieType die) {
    if (die == DieType.d100) {
      // Two d10s: tens 0..9, units 0..9. (0,0) -> 100.
      final tens = _rng.nextInt(10);
      final units = _rng.nextInt(10);
      final raw = tens * 10 + units;
      return RollResult(
        die: die,
        value: raw == 0 ? 100 : raw,
        tens: tens,
        units: units,
      );
    }
    return RollResult(die: die, value: _rng.nextInt(die.sides) + 1);
  }
}
