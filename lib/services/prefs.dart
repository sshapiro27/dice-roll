import 'package:shared_preferences/shared_preferences.dart';

import '../models/die.dart';

/// v1 persistence: remember the last selected die only.
class Prefs {
  static const _lastDieKey = 'last_die';

  Future<DieType> loadLastDie() async {
    final sp = await SharedPreferences.getInstance();
    final name = sp.getString(_lastDieKey);
    return DieType.values.firstWhere(
      (d) => d.name == name,
      orElse: () => DieType.d6,
    );
  }

  Future<void> saveLastDie(DieType die) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_lastDieKey, die.name);
  }
}
