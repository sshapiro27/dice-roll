import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Detects a physical shake (mobile). Tap and spacebar are handled in the
/// widget tree; shake is unreliable on web so callers must always also expose
/// a tap/key path.
class ShakeDetector {
  ShakeDetector({this.threshold = 22.0, this.cooldown = const Duration(milliseconds: 900)});

  final double threshold; // m/s^2 magnitude above gravity
  final Duration cooldown;

  StreamSubscription? _sub;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void start(void Function() onShake) {
    _sub ??= accelerometerEventStream().listen((e) {
      final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      // ~9.8 is gravity at rest; spikes well above indicate a shake.
      if (magnitude > threshold) {
        final now = DateTime.now();
        if (now.difference(_last) > cooldown) {
          _last = now;
          onShake();
        }
      }
    }, onError: (_) {/* no accelerometer (web/desktop) */});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
