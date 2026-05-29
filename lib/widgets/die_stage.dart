import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/die.dart';

/// Animated stone die: a fast, on-axis spin with per-roll randomized speed that
/// eases into a crisp still showing the rolled face. The result is decided
/// before the animation starts (passed in via [result]); the animation is
/// purely cosmetic and the face is NEVER revealed until the spin has finished.
class DieStage extends StatefulWidget {
  const DieStage({
    super.key,
    required this.result,
    required this.rollNonce,
    required this.onSettled,
  });

  final RollResult? result;
  final int rollNonce;
  final VoidCallback onSettled;

  @override
  State<DieStage> createState() => _DieStageState();
}

/// Per-roll randomized spin so no two rolls feel alike — but always on-axis.
class _Spin {
  _Spin(Random r)
      : seed = r.nextDouble() * pi * 2,
        dir = r.nextBool() ? 1.0 : -1.0,
        turns = 4.0 + r.nextDouble() * 4.0, // 4..8 full rotations
        ease = 1.7 + r.nextDouble() * 1.6, // decel curve shape
        wobbleAmp = 0.18 + r.nextDouble() * 0.28,
        wobbleFreq = 2.0 + r.nextDouble() * 3.0,
        wobblePh = r.nextDouble() * pi * 2;

  final double seed, dir, turns, ease, wobbleAmp, wobbleFreq, wobblePh;
}

class _DieStageState extends State<DieStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rng = Random();
  late _Spin _spin = _Spin(_rng);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onSettled();
      });
  }

  @override
  void didUpdateWidget(covariant DieStage old) {
    super.didUpdateWidget(old);
    if (widget.rollNonce != old.rollNonce && widget.result != null) {
      _spin = _Spin(_rng);
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return CustomPaint(
          size: const Size.square(240),
          painter: _StoneDiePainter(
            t: _c.value,
            result: widget.result,
            spin: _spin,
          ),
        );
      },
    );
  }
}

class _StoneDiePainter extends CustomPainter {
  _StoneDiePainter({required this.t, required this.result, required this.spin});

  final double t; // 0..1 animation progress
  final RollResult? result;
  final _Spin spin;

  static const _tumbleEnd = 0.72;

  // Randomized, irregular angular position for spin progress [p] (0..1).
  double _angle(double p) {
    final e = 1 - pow(1 - p, spin.ease).toDouble(); // fast then decelerating
    final base = spin.dir * spin.turns * 2 * pi * e;
    // Irregular speed so it doesn't look mechanically uniform.
    final wobble =
        spin.wobbleAmp * sin(spin.wobbleFreq * p * 2 * pi + spin.wobblePh) *
            (1 - p);
    return spin.seed + base + wobble;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.40;
    final sides = (result?.die.visualSides) ?? 6;

    final rolling = result != null;
    final tumbling = rolling && t < _tumbleEnd;

    final settleP = !rolling
        ? 1.0
        : t < _tumbleEnd
            ? 0.0
            : Curves.easeOutBack
                .transform((t - _tumbleEnd) / (1 - _tumbleEnd))
                .clamp(0.0, 1.0);

    // Die rises during tumble, then falls back to rest.
    final liftFactor = tumbling ? sin(pi * (t / _tumbleEnd)) : 0.0;
    final riseAmp = radius * 0.55;
    final dieCenter = center + Offset(0, -riseAmp * liftFactor);

    // Contact shadow shrinks and spreads as die lifts.
    final shadowK = (0.55 + 0.45 * settleP) * (1 - 0.5 * liftFactor);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, radius * 1.35),
        width: radius * 2.0 * shadowK,
        height: radius * 0.42 * shadowK,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5 * shadowK)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, 22 + 28 * liftFactor),
    );

    if (!rolling) {
      _drawDie(canvas, center, radius, sides, 0, alpha: 1, face: null);
      return;
    }

    if (tumbling) {
      final p = t / _tumbleEnd;
      // Ghost trails — subtle background blur, mostly for motion feel.
      const ghosts = 6;
      for (var i = ghosts; i >= 1; i--) {
        final lag = i * 0.08;
        final pp = (p - lag).clamp(0.0, 1.0);
        final blurSigma = i * 0.9; // reduced — ghosts are soft but not smeared
        final a = 0.10 + 0.09 * (1 - i / ghosts);
        canvas.saveLayer(
          null,
          Paint()
            ..imageFilter =
                ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        );
        _drawDie(canvas, dieCenter, radius, sides, _angle(pp),
            alpha: a, face: null);
        canvas.restore();
      }
      // Main die — strongly blurred at peak speed, clears as it decelerates.
      final spinBlur = 5.0 * (1 - p);
      canvas.saveLayer(
        null,
        Paint()
          ..imageFilter =
              ui.ImageFilter.blur(sigmaX: spinBlur, sigmaY: spinBlur),
      );
      _drawDie(canvas, dieCenter, radius, sides, _angle(p),
          alpha: 1.0, face: null);
      canvas.restore();
      return;
    }

    // Settle: small landing squash, reveal the face.
    final s = settleP;
    final bounce = (1 - s) * 0.16 * sin(t * 30);
    canvas.save();
    canvas.translate(dieCenter.dx, dieCenter.dy);
    canvas.transform((Matrix4.identity()
          ..scaleByDouble(1 + bounce, 1 - bounce, 1, 1))
        .storage);
    canvas.translate(-dieCenter.dx, -dieCenter.dy);
    _drawDie(canvas, dieCenter, radius * (0.94 + 0.06 * s), sides,
        (1 - s) * 0.12 * sin(t * 34),
        alpha: 1, face: result);
    canvas.restore();

    if (s > 0 && s < 0.6) {
      final dp = s / 0.6;
      final dust = Paint()
        ..color = const Color(0xFF9AA0A6).withValues(alpha: 0.16 * (1 - dp));
      for (var i = 0; i < 7; i++) {
        final ang = i * 2 * pi / 7;
        final d = radius * (0.9 + dp * 0.7);
        canvas.drawCircle(
          center +
              Offset(cos(ang), sin(ang) * 0.4) * d +
              Offset(0, radius * 1.1),
          (1 - dp) * 7 + 2,
          dust,
        );
      }
    }
  }

  // ---------------- die rendering ----------------

  void _drawDie(Canvas canvas, Offset center, double r, int sides,
      double rotation,
      {required double alpha, required RollResult? face}) {
    if (sides == 6) {
      _drawCube(canvas, center, r, rotation, alpha, face);
    } else {
      _drawPolygon(canvas, center, r, sides, rotation, alpha, face);
    }
  }

  Path _polyPath(Offset center, double r, int sides, double rotation) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final a = rotation - pi / 2 + i * 2 * pi / sides;
      final p = center + Offset(cos(a), sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // Cuts each corner of a regular polygon inward by [ch] pixels.
  Path _chamferedPolyPath(
      Offset center, double r, int sides, double rotation, double ch) {
    final pts = List.generate(sides, (i) {
      final a = rotation - pi / 2 + i * 2 * pi / sides;
      return center + Offset(cos(a), sin(a)) * r;
    });
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final prev = pts[(i + sides - 1) % sides];
      final curr = pts[i];
      final next = pts[(i + 1) % sides];
      final toPrev = (prev - curr) / (prev - curr).distance;
      final toNext = (next - curr) / (next - curr).distance;
      final p1 = curr + toPrev * ch;
      final p2 = curr + toNext * ch;
      i == 0 ? path.moveTo(p1.dx, p1.dy) : path.lineTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
    }
    return path..close();
  }

  void _drawCube(Canvas canvas, Offset center, double r, double rotation,
      double alpha, RollResult? face) {
    Offset v(int i) {
      final a = rotation - pi / 2 + i * pi / 3;
      return center + Offset(cos(a), sin(a)) * r;
    }

    final c = center;
    final v0 = v(0), v1 = v(1), v2 = v(2), v3 = v(3), v4 = v(4), v5 = v(5);

    Path fPath(Offset a, Offset b, Offset d, Offset e) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..lineTo(e.dx, e.dy)
      ..close();

    final topF = fPath(c, v5, v0, v1);
    final leftF = fPath(c, v5, v4, v3);
    final rightF = fPath(c, v1, v2, v3);

    final ch = r * 0.09;
    final chamfHex = _chamferedPolyPath(center, r, 6, rotation, ch);

    // Shadow cast by chamfered shape.
    canvas.drawPath(
      chamfHex.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    final rect = Rect.fromCircle(center: center, radius: r);
    Paint fill(Color a, Color b) => Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [a.withValues(alpha: alpha), b.withValues(alpha: alpha)],
      ).createShader(rect);

    // Faces + ridge lines clipped to chamfered boundary.
    canvas.save();
    canvas.clipPath(chamfHex);
    canvas.drawPath(topF, fill(const Color(0xFFC2C7CD), const Color(0xFFA5ABB3)));
    canvas.drawPath(leftF, fill(const Color(0xFF8C929B), const Color(0xFF6E747D)));
    canvas.drawPath(rightF, fill(const Color(0xFF5C616A), const Color(0xFF44484F)));
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(v5.dx, v5.dy)
        ..moveTo(c.dx, c.dy)
        ..lineTo(v1.dx, v1.dy)
        ..moveTo(c.dx, c.dy)
        ..lineTo(v3.dx, v3.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF2C2F34).withValues(alpha: alpha),
    );
    canvas.drawPath(
      Path()
        ..moveTo(v4.dx, v4.dy)
        ..lineTo(v5.dx, v5.dy)
        ..lineTo(v0.dx, v0.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.22 * alpha),
    );
    canvas.restore();

    // Chamfered outline drawn last so it sits cleanly on top.
    canvas.drawPath(
      chamfHex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF24262A).withValues(alpha: alpha),
    );

    if (face != null && face.die == DieType.d6) {
      final top = face.value;
      final left = (top % 6) + 1;
      final right = ((top + 1) % 6) + 1;
      _drawFacePips(canvas, c, v5 - c, v1 - c, top, r, alpha);
      _drawFacePips(canvas, c, v5 - c, v3 - c, left, r, alpha);
      _drawFacePips(canvas, c, v1 - c, v3 - c, right, r, alpha);
    }
  }

  /// Draws d6 pips on a face defined by origin [c] and edge vectors [ax]/[bx].
  /// [c] and axes [ax] (c→v5) and [bx] (c→v3). Pips are placed in face-local
  /// (u,v) space and the same affine maps them to skewed ellipses, so they sit
  /// flat on the angled face instead of looking like flat circles.
  void _drawFacePips(Canvas canvas, Offset c, Offset ax, Offset bx, int value,
      double r, double alpha) {
    const layout = {
      1: [Offset(0, 0)],
      2: [Offset(-1, -1), Offset(1, 1)],
      3: [Offset(-1, -1), Offset(0, 0), Offset(1, 1)],
      4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
      5: [
        Offset(-1, -1),
        Offset(1, -1),
        Offset(0, 0),
        Offset(-1, 1),
        Offset(1, 1)
      ],
      6: [
        Offset(-1, -1),
        Offset(1, -1),
        Offset(-1, 0),
        Offset(1, 0),
        Offset(-1, 1),
        Offset(1, 1)
      ],
    };
    final pips = layout[value] ?? const <Offset>[];

    // Affine: screen = c + u*ax + v*bx, with (u,v) in [0,1] over the face.
    final m = Matrix4.identity()
      ..setEntry(0, 0, ax.dx)
      ..setEntry(1, 0, ax.dy)
      ..setEntry(0, 1, bx.dx)
      ..setEntry(1, 1, bx.dy)
      ..setEntry(0, 3, c.dx)
      ..setEntry(1, 3, c.dy);

    canvas.save();
    canvas.transform(m.storage);
    const pipR = 0.085; // radius in face-UV units → becomes a skewed ellipse
    for (final o in pips) {
      // Map layout cell (-1..1) into the centre of the face.
      final cu = 0.5 + o.dx * 0.30;
      final cv = 0.5 + o.dy * 0.30;
      final rectUv =
          Rect.fromCircle(center: Offset(cu, cv), radius: pipR);
      canvas.drawCircle(
        Offset(cu, cv),
        pipR,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF15171A).withValues(alpha: alpha),
              const Color(0xFF30343A).withValues(alpha: alpha),
            ],
          ).createShader(rectUv),
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cu, cv + 0.006), radius: pipR),
        0.4,
        2.2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.012
          ..color = Colors.white.withValues(alpha: 0.16 * alpha),
      );
    }
    canvas.restore();
  }

  void _drawPolygon(Canvas canvas, Offset center, double r, int sides,
      double rotation, double alpha, RollResult? face) {
    final ch = r * 0.06;
    final body = _chamferedPolyPath(center, r, sides, rotation, ch);
    final rect = Rect.fromCircle(center: center, radius: r);

    canvas.drawPath(
      body.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFB9BEC4).withValues(alpha: alpha),
            const Color(0xFF6E747C).withValues(alpha: alpha),
            const Color(0xFF3C4046).withValues(alpha: alpha),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: [
            Colors.white.withValues(alpha: 0.10 * alpha),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28 * alpha),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );
    canvas.drawPath(
      _chamferedPolyPath(center, r * 0.965, sides, rotation, ch * 0.965),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.34 * alpha),
            Colors.black.withValues(alpha: 0.30 * alpha),
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF23262A).withValues(alpha: alpha),
    );

    if (face == null) return;
    final text = '${face.value}';
    TextPainter tp(Color color) => TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: r * (text.length > 2 ? 0.62 : 0.78),
              fontWeight: FontWeight.w800,
              color: color.withValues(alpha: alpha),
              letterSpacing: -1.5,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    final lo = tp(const Color(0xFF14161A));
    final base = center - Offset(lo.width / 2, lo.height / 2);
    tp(const Color(0xFF14161A)).paint(canvas, base + const Offset(0, 2));
    tp(const Color(0xFFDFE3E8)).paint(canvas, base - const Offset(0, 1.5));
    tp(const Color(0xFF8E949C)).paint(canvas, base);
  }

  @override
  bool shouldRepaint(covariant _StoneDiePainter old) =>
      old.t != t || old.result != result || old.spin != spin;
}
