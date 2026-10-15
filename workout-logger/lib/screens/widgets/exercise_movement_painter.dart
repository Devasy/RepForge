import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/exercise_animations.dart';
import '../../theme/app_theme.dart';

/// A normalized joint diagram. Limbs use two-link inverse kinematics so a
/// moving hand/foot does not stretch the illustrated upper/lower limb.
class ExercisePose {
  const ExercisePose({
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.ankle,
    required this.elbow,
    required this.hand,
    this.otherHand,
    this.otherElbow,
    this.otherKnee,
    this.otherAnkle,
    this.front = false,
  });
  final Offset shoulder, hip, knee, ankle, elbow, hand;
  final Offset? otherHand, otherElbow, otherKnee, otherAnkle;
  final bool front;

  Offset get head {
    final direction = shoulder - hip;
    return shoulder + direction / direction.distance * 24;
  }

  static Offset joint(
    Offset a,
    Offset b,
    double upper,
    double lower, {
    double bend = 1,
  }) {
    final delta = b - a;
    final distance = delta.distance.clamp(0.001, upper + lower - 0.001);
    final along =
        ((upper * upper - lower * lower + distance * distance) / (2 * distance))
            .clamp(-upper, upper);
    final height = math.sqrt(math.max(0, upper * upper - along * along));
    final unit = delta / math.max(delta.distance, 0.001);
    return a + unit * along + Offset(-unit.dy, unit.dx) * height * bend;
  }

  static ExercisePose at(ExerciseAnimation spec, double amount) {
    final t = amount.clamp(0.0, 1.0);
    switch (spec.movement) {
      case ExerciseMovement.benchPress:
      case ExerciseMovement.skullCrusher:
        final shoulder = spec.incline
            ? const Offset(123, 117)
            : const Offset(120, 151);
        final hand = spec.movement == ExerciseMovement.skullCrusher
            ? Offset.lerp(const Offset(85, 114), const Offset(125, 75), t)!
            : Offset.lerp(
                shoulder + const Offset(13, -25),
                shoulder + const Offset(0, -76),
                t,
              )!;
        final elbow = spec.movement == ExerciseMovement.skullCrusher
            ? const Offset(121, 110)
            : joint(shoulder, hand, 39, 39, bend: 1);
        return ExercisePose(
          shoulder: shoulder,
          hip: const Offset(200, 155),
          knee: const Offset(244, 175),
          ankle: const Offset(238, 215),
          elbow: elbow,
          hand: hand,
        );
      case ExerciseMovement.pushUp:
      case ExerciseMovement.plank:
        final hold = spec.isHold;
        final shoulder = Offset(145, hold ? 166 : 124 + 38 * t);
        final hip = Offset(235, hold ? 188 : 163 + 20 * t);
        final hand = hold ? const Offset(115, 213) : const Offset(137, 213);
        return ExercisePose(
          shoulder: shoulder,
          hip: hip,
          knee: Offset.lerp(hip, const Offset(305, 213), .55)!,
          ankle: const Offset(305, 213),
          elbow: hold
              ? const Offset(151, 211)
              : joint(shoulder, hand, 46, 46, bend: -1),
          hand: hand,
        );
      case ExerciseMovement.deadlift:
        final hip = Offset(204 - 39 * t, 152 - 30 * t);
        final shoulder = Offset(152 + 12 * t, 111 - 57 * t);
        final ankle = const Offset(153, 213);
        final knee = spec.hinge
            ? Offset(160, 167 - 2 * t)
            : joint(hip, ankle, 48, 48);
        final hand = Offset(150 + 13 * t, 197 - 65 * t);
        return ExercisePose(
          shoulder: shoulder,
          hip: hip,
          knee: knee,
          ankle: ankle,
          elbow: joint(shoulder, hand, 43, 43, bend: -1),
          hand: hand,
        );
      case ExerciseMovement.squat:
      case ExerciseMovement.lunge:
        final lunge = spec.movement == ExerciseMovement.lunge;
        final hip = Offset(
          lunge ? 176 : 167 + 32 * t,
          122 + (lunge ? 41 : 45) * t,
        );
        final shoulder = hip + Offset(lunge ? -3 : -8 - 22 * t, -68);
        final ankle = Offset(lunge ? 126 : 152, 213);
        final knee = joint(hip, ankle, 50, 50);
        final hand = lunge
            ? shoulder + const Offset(8, 78)
            : shoulder + const Offset(24, 14);
        return ExercisePose(
          shoulder: shoulder,
          hip: hip,
          knee: knee,
          ankle: ankle,
          elbow: joint(shoulder, hand, 40, 40),
          hand: hand,
          otherAnkle: lunge ? const Offset(250, 213) : null,
          otherKnee: lunge
              ? joint(hip, const Offset(250, 213), 50, 50, bend: 1)
              : null,
        );
      case ExerciseMovement.legPress:
        final ankle = Offset.lerp(
          const Offset(213, 123),
          const Offset(264, 75),
          t,
        )!;
        const hip = Offset(153, 163);
        return ExercisePose(
          shoulder: const Offset(112, 113),
          hip: hip,
          knee: joint(hip, ankle, 67, 65, bend: -1),
          ankle: ankle,
          elbow: const Offset(115, 153),
          hand: const Offset(139, 169),
        );
      case ExerciseMovement.legExtension:
        final ankle = Offset.lerp(
          const Offset(221, 214),
          const Offset(277, 158),
          t,
        )!;
        return ExercisePose(
          shoulder: const Offset(156, 91),
          hip: const Offset(155, 157),
          knee: const Offset(219, 158),
          ankle: ankle,
          elbow: const Offset(146, 131),
          hand: const Offset(160, 166),
        );
      case ExerciseMovement.legCurl:
        final angle = -t * math.pi * .65;
        final ankle =
            const Offset(231, 150) +
            Offset(math.cos(angle), math.sin(angle)) * 59;
        return ExercisePose(
          shoulder: const Offset(106, 151),
          hip: const Offset(176, 150),
          knee: const Offset(231, 150),
          ankle: ankle,
          elbow: const Offset(93, 173),
          hand: const Offset(113, 183),
        );
      case ExerciseMovement.hipThrust:
        final hip = Offset(199, 175 - 36 * t);
        return ExercisePose(
          shoulder: const Offset(126, 135),
          hip: hip,
          knee: const Offset(249, 156),
          ankle: const Offset(250, 213),
          elbow: const Offset(153, 151),
          hand: hip,
        );
      case ExerciseMovement.crunch:
      case ExerciseMovement.legRaise:
      case ExerciseMovement.twist:
        return _core(spec, t);
      default:
        return _upright(spec, t);
    }
  }

  static ExercisePose _core(ExerciseAnimation spec, double t) {
    const hip = Offset(183, 193);
    if (spec.movement == ExerciseMovement.twist) {
      final shoulder = Offset(160 + 12 * t, 131);
      final hand = Offset(113 + 112 * t, 154);
      return ExercisePose(
        shoulder: shoulder,
        hip: hip,
        knee: const Offset(242, 171),
        ankle: const Offset(282, 203),
        elbow: joint(shoulder, hand, 35, 35),
        hand: hand,
        otherHand: hand + const Offset(8, 0),
        otherElbow: joint(
          shoulder + const Offset(18, 0),
          hand + const Offset(8, 0),
          35,
          35,
        ),
        front: true,
      );
    }
    final raisingLegs = spec.movement == ExerciseMovement.legRaise;
    final angle = -t * math.pi / 2;
    final ankle = raisingLegs
        ? hip + Offset(math.cos(angle), math.sin(angle)) * 113
        : const Offset(285, 209);
    final shoulder = raisingLegs
        ? const Offset(105, 193)
        : Offset(108 + 15 * t, 193 - 27 * t);
    final hand = raisingLegs
        ? const Offset(170, 207)
        : shoulder + const Offset(-5, -9);
    return ExercisePose(
      shoulder: shoulder,
      hip: hip,
      knee: raisingLegs ? Offset.lerp(hip, ankle, .5)! : const Offset(235, 155),
      ankle: ankle,
      elbow: raisingLegs
          ? const Offset(131, 207)
          : shoulder + const Offset(29, -9),
      hand: hand,
    );
  }

  static ExercisePose _upright(ExerciseAnimation spec, double t) {
    final front = {
      ExerciseMovement.fly,
      ExerciseMovement.lateralRaise,
      ExerciseMovement.rearFly,
      ExerciseMovement.shoulderPress,
      ExerciseMovement.facePull,
      ExerciseMovement.pullDown,
      ExerciseMovement.pullUp,
    }.contains(spec.movement);
    var hip = spec.seated ? const Offset(164, 150) : const Offset(172, 128);
    var shoulder = spec.seated ? const Offset(164, 85) : const Offset(170, 64);
    var ankle = spec.seated ? const Offset(226, 213) : const Offset(160, 213);
    var knee = spec.seated ? const Offset(218, 154) : const Offset(164, 172);
    if (front && !spec.seated) {
      knee = const Offset(150, 173);
      ankle = const Offset(145, 213);
    }
    if (front && spec.seated) {
      knee = const Offset(145, 173);
      ankle = const Offset(145, 213);
    }
    if (spec.hinge) {
      shoulder = const Offset(133, 104);
      hip = const Offset(193, 139);
      knee = const Offset(159, 174);
    }
    if (spec.movement == ExerciseMovement.tricepsExtension) {
      shoulder += const Offset(0, 16);
      hip += const Offset(0, 16);
    }
    var hand = shoulder + const Offset(8, 78);
    Offset? elbow, otherHand, otherElbow;
    switch (spec.movement) {
      case ExerciseMovement.curl:
        final origin =
            shoulder +
            (spec.supported ? const Offset(-20, 31) : const Offset(1, 40));
        final angle = .35 - t * 2.35;
        hand = origin + Offset(math.sin(angle), math.cos(angle)) * 39;
        elbow = origin;
      case ExerciseMovement.pushDown:
        elbow = shoulder + const Offset(5, 39);
        hand =
            elbow +
            Offset(-math.sin((1 - t) * 1.5), math.cos((1 - t) * 1.5)) * 40;
      case ExerciseMovement.tricepsExtension:
        elbow = shoulder + const Offset(-3, -33);
        final angle = (1 - t) * 2.5;
        hand = elbow + Offset(math.sin(angle), -math.cos(angle)) * 36;
      case ExerciseMovement.shoulderPress:
        hand = shoulder + Offset(-54 + 27 * t, -4 - 49 * t);
        otherHand = shoulder + Offset(54 - 27 * t, -4 - 49 * t);
      case ExerciseMovement.fly:
        hand = shoulder + Offset(-75 + 60 * t, 17);
        otherHand = shoulder + Offset(75 - 60 * t, 17);
      case ExerciseMovement.lateralRaise:
      case ExerciseMovement.rearFly:
        final angle = .15 + t * math.pi / 2;
        hand = shoulder + Offset(-math.sin(angle), math.cos(angle)) * 79;
        otherHand = shoulder + Offset(math.sin(angle), math.cos(angle)) * 79;
      case ExerciseMovement.frontRaise:
        final angle = t * math.pi / 2;
        hand = shoulder + Offset(-math.sin(angle), math.cos(angle)) * 79;
      case ExerciseMovement.shrug:
        shoulder -= Offset(0, 8 * t);
        hand = shoulder + const Offset(8, 78);
      case ExerciseMovement.calfRaise:
        hip -= Offset(0, 10 * t);
        shoulder -= Offset(0, 10 * t);
        knee -= Offset(0, 10 * t);
        ankle -= Offset(0, 10 * t);
        hand = shoulder + const Offset(8, 78);
      case ExerciseMovement.row:
        hand = spec.seated
            ? Offset.lerp(const Offset(92, 137), const Offset(146, 145), t)!
            : Offset.lerp(const Offset(130, 180), const Offset(178, 146), t)!;
      case ExerciseMovement.facePull:
        hand = shoulder + Offset(-64 + 24 * t, 6 - 20 * t);
        otherHand = shoulder + Offset(64 - 24 * t, 6 - 20 * t);
      case ExerciseMovement.pullDown:
      case ExerciseMovement.pullUp:
        final pullingBody = spec.movement == ExerciseMovement.pullUp;
        if (pullingBody) {
          shoulder = Offset(170, 94 - 43 * t);
          hip = shoulder + const Offset(0, 64);
          knee = hip + const Offset(-18, 33);
          ankle = knee + const Offset(16, 26);
          hand = const Offset(124, 29);
          otherHand = const Offset(216, 29);
        } else {
          hand = shoulder + Offset(-48, -56 + 78 * t);
          otherHand = shoulder + Offset(48, -56 + 78 * t);
        }
      case ExerciseMovement.dip:
        shoulder = Offset(168, 63 + 30 * t);
        hip = shoulder + const Offset(8, 63);
        knee = hip + const Offset(-24, 38);
        ankle = knee + const Offset(22, 23);
        hand = const Offset(155, 139);
      case ExerciseMovement.cableCrunch:
        hip = const Offset(179, 155);
        shoulder = Offset(167 - 25 * t, 91 + 35 * t);
        knee = const Offset(215, 198);
        ankle = const Offset(269, 204);
        hand = shoulder + const Offset(-9, -12);
      default:
        break;
    }
    final armRoot = shoulder + Offset(front ? -13 : 0, 0);
    elbow ??= joint(armRoot, hand, 40, 40, bend: front ? -1 : 1);
    if (otherHand != null) {
      otherElbow = joint(shoulder + const Offset(13, 0), otherHand, 40, 40);
    }
    return ExercisePose(
      shoulder: shoulder,
      hip: hip,
      knee: knee,
      ankle: ankle,
      elbow: elbow,
      hand: hand,
      otherHand: otherHand,
      otherElbow: otherElbow,
      otherKnee: front && !spec.hinge ? Offset(194, knee.dy) : null,
      otherAnkle: front && !spec.hinge ? Offset(195, ankle.dy) : null,
      front: front,
    );
  }
}

class ExerciseMovementPainter extends CustomPainter {
  ExerciseMovementPainter({
    required this.animation,
    required this.amount,
    required this.muscleColor,
  });
  final ExerciseAnimation animation;
  final double amount;
  final Color muscleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final wide = {
      ExerciseMovement.benchPress,
      ExerciseMovement.skullCrusher,
      ExerciseMovement.pushUp,
      ExerciseMovement.plank,
      ExerciseMovement.legCurl,
      ExerciseMovement.hipThrust,
      ExerciseMovement.crunch,
      ExerciseMovement.legRaise,
    }.contains(animation.movement);
    final scene = Rect.fromLTWH(wide ? 20 : 40, -10, wide ? 320 : 280, 245);
    final scale = math.min(
      size.width / scene.width,
      size.height / scene.height,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(
      (size.width - scene.width * scale) / 2 - scene.left * scale,
      (size.height - scene.height * scale) / 2 - scene.top * scale,
    );
    canvas.scale(scale);
    final pose = ExercisePose.at(animation, amount);
    _equipmentBehind(canvas, pose);
    _body(canvas, pose);
    _equipmentInFront(canvas, pose);
    canvas.restore();
  }

  void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
  void _support(Canvas c, Offset a, Offset b) =>
      _line(c, a, b, AppColors.textMuted, 5);

  void _equipmentBehind(Canvas c, ExercisePose p) {
    _line(
      c,
      const Offset(45, 221),
      const Offset(315, 221),
      AppColors.glassBorderStrong,
      1.5,
    );
    final movement = animation.movement;
    if ({
      ExerciseMovement.benchPress,
      ExerciseMovement.skullCrusher,
      ExerciseMovement.legCurl,
    }.contains(movement)) {
      final a = animation.incline
          ? const Offset(87, 116)
          : const Offset(75, 166);
      _line(c, a, const Offset(202, 168), AppColors.textMuted, 10);
      _support(c, const Offset(96, 172), const Offset(96, 217));
      _support(c, const Offset(195, 172), const Offset(195, 217));
    }
    if (animation.seated || movement == ExerciseMovement.hipThrust) {
      final left = movement == ExerciseMovement.hipThrust ? 94.0 : 144.0;
      final y = movement == ExerciseMovement.hipThrust ? 143.0 : 169.0;
      _line(c, Offset(left, y), Offset(left + 58, y), AppColors.textMuted, 9);
      _support(c, Offset(left + 10, y + 5), Offset(left + 10, 217));
    }
    if (movement == ExerciseMovement.legPress) {
      _line(
        c,
        const Offset(95, 119),
        const Offset(139, 171),
        AppColors.textMuted,
        11,
      );
      _support(c, const Offset(155, 209), const Offset(291, 66));
      _line(
        c,
        p.ankle + const Offset(-18, -17),
        p.ankle + const Offset(18, 17),
        AppColors.textSoft,
        7,
      );
    }
    if (movement == ExerciseMovement.pullUp) {
      _support(c, const Offset(93, 28), const Offset(247, 28));
      _support(c, const Offset(99, 29), const Offset(99, 217));
      _support(c, const Offset(241, 29), const Offset(241, 217));
    }
    if (movement == ExerciseMovement.dip) {
      _support(c, const Offset(128, 140), const Offset(185, 140));
      _support(c, const Offset(139, 140), const Offset(139, 218));
    }
    if (movement == ExerciseMovement.calfRaise) {
      _support(c, const Offset(130, 222), const Offset(184, 222));
      _support(c, const Offset(212, 62), const Offset(212, 217));
      _support(c, const Offset(212, 62), p.shoulder + const Offset(12, -4));
    }
    if (animation.supported && movement == ExerciseMovement.curl) {
      _line(
        c,
        const Offset(128, 110),
        const Offset(147, 147),
        AppColors.textMuted,
        9,
      );
      _support(c, const Offset(134, 143), const Offset(127, 217));
    }
    if (animation.supported &&
        movement == ExerciseMovement.row &&
        animation.equipment == ExerciseEquipment.dumbbell) {
      _line(
        c,
        const Offset(208, 137),
        const Offset(268, 137),
        AppColors.textMuted,
        9,
      );
      _support(c, const Offset(250, 142), const Offset(250, 217));
      _line(
        c,
        p.shoulder + const Offset(8, 0),
        const Offset(225, 132),
        AppColors.textMuted,
        11,
      );
    }
    if (animation.equipment == ExerciseEquipment.cable) {
      final anchor = switch (movement) {
        ExerciseMovement.row => const Offset(55, 139),
        ExerciseMovement.fly ||
        ExerciseMovement.facePull => const Offset(53, 61),
        _ => const Offset(128, 14),
      };
      _line(c, anchor, p.hand, AppColors.textMuted, 1.5);
      c.drawCircle(anchor, 6, Paint()..color = AppColors.textSoft);
      if (p.otherHand != null) {
        _line(c, const Offset(290, 61), p.otherHand!, AppColors.textMuted, 1.5);
      }
    }
  }

  void _body(Canvas c, ExercisePose p) {
    final front = p.front;
    final near = AppColors.textPrimary;
    final far = near.withValues(alpha: .55);
    final legs = {
      ExerciseMovement.squat,
      ExerciseMovement.lunge,
      ExerciseMovement.legPress,
      ExerciseMovement.legExtension,
      ExerciseMovement.legCurl,
      ExerciseMovement.deadlift,
      ExerciseMovement.calfRaise,
      ExerciseMovement.hipThrust,
    }.contains(animation.movement);
    final arms = {
      ExerciseMovement.curl,
      ExerciseMovement.pushDown,
      ExerciseMovement.skullCrusher,
      ExerciseMovement.tricepsExtension,
      ExerciseMovement.shoulderPress,
      ExerciseMovement.lateralRaise,
      ExerciseMovement.frontRaise,
    }.contains(animation.movement);
    final calf = animation.movement == ExerciseMovement.calfRaise;
    final shift = front ? const Offset(12, 0) : const Offset(10, -2);
    final farAnkle = p.otherAnkle ?? p.ankle + shift;
    _limb(
      c,
      p.hip + shift,
      p.otherKnee ?? p.knee + shift,
      farAnkle,
      far,
      24,
      highlight: legs ? muscleColor.withValues(alpha: .55) : null,
      calf: calf,
    );
    _shoe(c, farAnkle, far, calf: calf);
    if (p.otherHand != null) {
      _limb(
        c,
        p.shoulder + const Offset(13, 0),
        p.otherElbow!,
        p.otherHand!,
        far,
        16,
        highlight: arms ? muscleColor.withValues(alpha: .55) : null,
      );
    } else {
      _limb(
        c,
        p.shoulder + shift,
        p.elbow + shift,
        p.hand + shift,
        far,
        16,
        highlight: arms ? muscleColor.withValues(alpha: .55) : null,
      );
    }
    _limb(
      c,
      p.hip,
      p.knee,
      p.ankle,
      near,
      26,
      highlight: legs ? muscleColor : null,
      calf: calf,
    );
    _shoe(c, p.ankle, near, calf: calf);

    final axis = p.hip - p.shoulder;
    final normal = Offset(-axis.dy, axis.dx) / axis.distance;
    final upper = p.shoulder + axis * .18;
    final waist = p.shoulder + axis * .62;
    final torso = Path()
      ..moveTo((p.shoulder + normal * 17).dx, (p.shoulder + normal * 17).dy)
      ..cubicTo(
        (upper + normal * 21).dx,
        (upper + normal * 21).dy,
        (waist + normal * 11).dx,
        (waist + normal * 11).dy,
        (p.hip + normal * 16).dx,
        (p.hip + normal * 16).dy,
      )
      ..quadraticBezierTo(
        (p.hip + axis / axis.distance * 10).dx,
        (p.hip + axis / axis.distance * 10).dy,
        (p.hip - normal * 16).dx,
        (p.hip - normal * 16).dy,
      )
      ..cubicTo(
        (waist - normal * 11).dx,
        (waist - normal * 11).dy,
        (upper - normal * 21).dx,
        (upper - normal * 21).dy,
        (p.shoulder - normal * 17).dx,
        (p.shoulder - normal * 17).dy,
      )
      ..quadraticBezierTo(
        p.shoulder.dx,
        p.shoulder.dy - 6,
        (p.shoulder + normal * 17).dx,
        (p.shoulder + normal * 17).dy,
      )
      ..close();
    c.drawPath(torso, Paint()..color = AppColors.card);
    if (!legs && !arms) {
      c.save();
      c.clipPath(torso);
      _line(
        c,
        Offset.lerp(p.shoulder, p.hip, .23)!,
        Offset.lerp(p.shoulder, p.hip, .62)!,
        muscleColor,
        24,
      );
      c.restore();
    }
    c.drawPath(
      torso,
      Paint()
        ..color = near
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _line(c, p.shoulder, p.head, near, 11);
    c.drawOval(
      Rect.fromCenter(center: p.head, width: 27, height: 31),
      Paint()..color = near,
    );
    final root = p.shoulder + Offset(front ? -13 : 0, 0);
    _limb(
      c,
      root,
      p.elbow,
      p.hand,
      near,
      18,
      highlight: arms ? muscleColor : null,
    );
    c.drawCircle(p.hand, 6, Paint()..color = near);
  }

  void _limb(
    Canvas c,
    Offset a,
    Offset joint,
    Offset end,
    Color color,
    double width, {
    Color? highlight,
    bool calf = false,
  }) {
    _segment(
      c,
      a,
      joint,
      width / 2,
      width * .36,
      color,
      highlight: calf ? null : highlight,
    );
    _segment(
      c,
      joint,
      end,
      width * .36,
      width * .24,
      color,
      highlight: calf ? highlight : null,
    );
    c.drawCircle(joint, width * .23, Paint()..color = AppColors.card);
    c.drawCircle(
      joint,
      width * .23,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _segment(
    Canvas c,
    Offset a,
    Offset b,
    double startRadius,
    double endRadius,
    Color color, {
    Color? highlight,
  }) {
    final delta = b - a;
    if (delta.distance < .001) return;
    final direction = delta / delta.distance;
    final normal = Offset(-direction.dy, direction.dx);
    final center = Offset.lerp(a, b, .5)!;
    final path = Path()
      ..moveTo((a + normal * startRadius).dx, (a + normal * startRadius).dy)
      ..quadraticBezierTo(
        (center + normal * (startRadius + 3)).dx,
        (center + normal * (startRadius + 3)).dy,
        (b + normal * endRadius).dx,
        (b + normal * endRadius).dy,
      )
      ..quadraticBezierTo(
        (b + direction * endRadius).dx,
        (b + direction * endRadius).dy,
        (b - normal * endRadius).dx,
        (b - normal * endRadius).dy,
      )
      ..quadraticBezierTo(
        (center - normal * (startRadius + 3)).dx,
        (center - normal * (startRadius + 3)).dy,
        (a - normal * startRadius).dx,
        (a - normal * startRadius).dy,
      )
      ..quadraticBezierTo(
        (a - direction * startRadius).dx,
        (a - direction * startRadius).dy,
        (a + normal * startRadius).dx,
        (a + normal * startRadius).dy,
      )
      ..close();
    c.drawPath(path, Paint()..color = highlight ?? color);
    c.drawPath(
      path,
      Paint()
        ..color = highlight == null ? AppColors.card : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  void _shoe(Canvas c, Offset ankle, Color color, {bool calf = false}) {
    final toe = calf ? Offset(146, 219) : ankle + const Offset(-19, 7);
    final path = Path()
      ..moveTo(ankle.dx - 5, ankle.dy - 2)
      ..quadraticBezierTo(ankle.dx - 10, ankle.dy + 2, toe.dx, toe.dy - 4)
      ..quadraticBezierTo(toe.dx - 4, toe.dy, toe.dx, toe.dy + 1)
      ..lineTo(ankle.dx + 8, ankle.dy + 8)
      ..quadraticBezierTo(ankle.dx + 8, ankle.dy, ankle.dx + 4, ankle.dy - 3)
      ..close();
    c.drawPath(path, Paint()..color = AppColors.card);
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _weight(Canvas c, Offset hand, {bool vertical = false}) {
    final axis = vertical ? const Offset(0, 13) : const Offset(15, 0);
    _line(c, hand - axis, hand + axis, AppColors.cyan, 4);
    for (final sign in [-1.0, 1.0]) {
      final center = hand + axis * sign;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: vertical ? 19 : 7,
            height: vertical ? 7 : 23,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = AppColors.cyan,
      );
    }
  }

  void _equipmentInFront(Canvas c, ExercisePose p) {
    if (animation.movement == ExerciseMovement.row &&
        animation.supported &&
        animation.equipment == ExerciseEquipment.barbell) {
      const pivot = Offset(292, 217);
      _line(c, pivot, p.hand, AppColors.textMuted, 4);
      c.drawCircle(
        Offset.lerp(p.hand, pivot, .16)!,
        13,
        Paint()..color = AppColors.cyan,
      );
      _line(
        c,
        p.hand - const Offset(10, 0),
        p.hand + const Offset(10, 0),
        AppColors.textPrimary,
        4,
      );
      return;
    }
    if (animation.equipment == ExerciseEquipment.barbell) {
      var center = p.hand;
      if (animation.movement == ExerciseMovement.squat) {
        center = p.shoulder + const Offset(3, -6);
      }
      if (animation.movement == ExerciseMovement.hipThrust) {
        center = p.hip;
      }
      final half = p.front ? 64.0 : 31.0;
      _line(
        c,
        center - Offset(half, 0),
        center + Offset(half, 0),
        AppColors.cyan,
        4,
      );
      for (final sign in [-1.0, 1.0]) {
        final plate = center + Offset(half * .8 * sign, 0);
        final rect = Rect.fromCenter(
          center: plate,
          width: p.front ? 12 : 20,
          height: 38,
        );
        c.drawOval(
          rect.shift(const Offset(3, 0)),
          Paint()..color = AppColors.card,
        );
        c.drawOval(
          rect.shift(const Offset(3, 0)),
          Paint()
            ..color = AppColors.cyan
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        c.drawOval(rect, Paint()..color = AppColors.card);
        c.drawOval(
          rect,
          Paint()
            ..color = AppColors.cyan
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        c.drawCircle(plate, 3, Paint()..color = AppColors.cyan);
      }
    } else if (animation.equipment == ExerciseEquipment.dumbbell) {
      _weight(c, p.hand, vertical: animation.movement == ExerciseMovement.curl);
      if (p.otherHand != null) {
        _weight(c, p.otherHand!);
      }
    } else if (animation.equipment == ExerciseEquipment.cable) {
      if (animation.movement == ExerciseMovement.pullDown) {
        _line(
          c,
          p.hand - const Offset(10, 0),
          p.otherHand! + const Offset(10, 0),
          AppColors.cyan,
          4,
        );
      } else {
        _line(
          c,
          p.hand - const Offset(5, 4),
          p.hand + const Offset(5, 4),
          AppColors.cyan,
          4,
        );
      }
    } else if (animation.movement == ExerciseMovement.fly) {
      for (final hand in [p.hand, p.otherHand!]) {
        _line(
          c,
          hand + const Offset(0, -8),
          hand + const Offset(0, 8),
          AppColors.cyan,
          6,
        );
      }
    } else if (animation.movement == ExerciseMovement.calfRaise) {
      _line(
        c,
        p.shoulder + const Offset(-12, -4),
        p.shoulder + const Offset(12, -4),
        AppColors.cyan,
        7,
      );
    } else if (animation.movement == ExerciseMovement.legCurl ||
        animation.movement == ExerciseMovement.legExtension) {
      _line(
        c,
        p.ankle - const Offset(8, 0),
        p.ankle + const Offset(8, 0),
        AppColors.cyan,
        9,
      );
    }
  }

  @override
  bool shouldRepaint(ExerciseMovementPainter oldDelegate) =>
      oldDelegate.amount != amount ||
      oldDelegate.animation != animation ||
      oldDelegate.muscleColor != muscleColor;
}
