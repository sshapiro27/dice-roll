import 'dart:async';

import '../models/die.dart';

/// Central roll API. UI calls [roll]; v2 (history/stats) and v3 (game) will
/// subscribe to [events] without touching the roller code.
class RollEngine {
  RollEngine([Dice? dice]) : _dice = dice ?? Dice();

  final Dice _dice;
  final _controller = StreamController<RollResult>.broadcast();

  Stream<RollResult> get events => _controller.stream;

  RollResult roll(DieType die) {
    final result = _dice.roll(die);
    _controller.add(result);
    return result;
  }

  void dispose() => _controller.close();
}
