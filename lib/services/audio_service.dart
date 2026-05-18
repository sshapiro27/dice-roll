import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

/// Plays the deep stone roll clip with small random pitch/volume jitter so
/// repeated rolls never sound identical.
class AudioService {
  final _player = AudioPlayer(playerId: 'stone_roll');
  final _rng = Random();
  bool _ready = false;

  Future<void> init() async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setSource(AssetSource('audio/dice-roll.mp3'));
    _ready = true;
  }

  Future<void> playRoll() async {
    if (!_ready) return;
    final volume = 0.85 + _rng.nextDouble() * 0.15; // 0.85..1.0
    final rate = 0.92 + _rng.nextDouble() * 0.16; // 0.92..1.08
    await _player.stop();
    await _player.setVolume(volume);
    try {
      await _player.setPlaybackRate(rate);
    } catch (_) {
      // Playback rate unsupported on some web backends; ignore.
    }
    await _player.resume();
  }

  void dispose() => _player.dispose();
}
