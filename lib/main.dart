import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/roll_engine.dart';
import 'models/die.dart';
import 'services/audio_service.dart';
import 'services/prefs.dart';
import 'services/roll_input.dart';
import 'widgets/die_selector.dart';
import 'widgets/die_stage.dart';

void main() => runApp(const StoneDiceApp());

class StoneDiceApp extends StatelessWidget {
  const StoneDiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stone Dice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121316),
        useMaterial3: true,
      ),
      home: const RollerScreen(),
    );
  }
}

class RollerScreen extends StatefulWidget {
  const RollerScreen({super.key});

  @override
  State<RollerScreen> createState() => _RollerScreenState();
}

class _RollerScreenState extends State<RollerScreen> {
  final _engine = RollEngine();
  final _audio = AudioService();
  final _prefs = Prefs();
  final _shake = ShakeDetector();
  final _focus = FocusNode();

  DieType _die = DieType.d6;
  RollResult? _result;
  int _nonce = 0;
  bool _rolling = false;

  @override
  void initState() {
    super.initState();
    _audio.init();
    _prefs.loadLastDie().then((d) {
      if (mounted) setState(() => _die = d);
    });
    _shake.start(_roll);
  }

  @override
  void dispose() {
    _shake.stop();
    _audio.dispose();
    _engine.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _selectDie(DieType d) {
    if (_rolling) return;
    setState(() => _die = d);
    _prefs.saveLastDie(d);
  }

  void _roll() {
    if (_rolling) return; // ignore taps mid-roll
    setState(() {
      _rolling = true;
      _result = _engine.roll(_die);
      _nonce++;
    });
    _audio.playRoll();
  }

  void _onSettled() {
    HapticFeedback.mediumImpact(); // no-op on web
    if (mounted) setState(() => _rolling = false);
  }

  String _subtitle() {
    if (_result == null) return 'tap, press space, or shake to roll';
    if (_result!.isPercentile) {
      return 'd100  ·  ${_result!.tens! * 10}+${_result!.units}';
    }
    return _die.label;
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.space) {
          _roll();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'STONE DICE',
                style: TextStyle(
                  color: Color(0xFF8A8F96),
                  letterSpacing: 6,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _roll,
                          behavior: HitTestBehavior.opaque,
                          child: DieStage(
                            result: _result,
                            rollNonce: _nonce,
                            onSettled: _onSettled,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _subtitle(),
                          style: const TextStyle(
                              color: Color(0xFF6B7077), fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              DieSelector(selected: _die, onChanged: _selectDie),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
