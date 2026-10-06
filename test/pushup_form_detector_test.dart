import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_pose_detector/live_pose_detector.dart';

/// Builds a synthetic side-view push-up [Pose] on a horizontal body line
/// (shoulder at x=0, hip at x=100, ankle at x=200 — all y=0 when
/// perfectly straight) so every deviation below is just a `y` offset,
/// scaled to land at an exact fraction of the relevant line's length.
///
/// This matches [PushUpFormDetector]'s own line choices (shoulder→ankle
/// for hips, shoulder→hip for the head, hip→ankle for knees) so a
/// `*DeviationFrac` here lands at exactly that fraction in
/// `signedLandmarkLineDeviation`.
Pose buildPose({
  double elbowAngleDeg = 170,
  double abductionAngleDeg = 35,
  double hipDeviationFrac = 0,
  double headDeviationFrac = 0,
  double kneeDeviationFrac = 0,
  double bodyAngleDeg = 0,
}) {
  const shoulder = Offset(0, 0);
  const hip = Offset(100, 0);
  const ankle = Offset(200, 0);
  final hipPoint = Offset(hip.dx, hipDeviationFrac * 200);
  final ear = Offset(-30, headDeviationFrac * 100);
  final knee = Offset(150, hipPoint.dy + kneeDeviationFrac * 100);

  final abductionRad = abductionAngleDeg * math.pi / 180;
  final elbowDir = Offset(math.cos(abductionRad), math.sin(abductionRad));
  final elbow = shoulder + elbowDir * 40;
  final wristDir = _rotate(elbowDir, 180 - elbowAngleDeg);
  final wrist = elbow + wristDir * 35;

  // Rotate everything but the shoulder (origin) by bodyAngleDeg — used to
  // simulate the whole body pivoting relative to the camera (e.g.
  // standing up out of a push-up), independent of arm geometry above.
  Offset rotated(Offset p) => bodyAngleDeg == 0 ? p : _rotate(p, bodyAngleDeg);

  PoseLandmark lm(PoseLandmarkType type, Offset p) =>
      PoseLandmark(type: type, x: p.dx, y: p.dy, z: 0, likelihood: 0.95);

  return Pose(
    landmarks: {
      PoseLandmarkType.leftShoulder:
          lm(PoseLandmarkType.leftShoulder, shoulder),
      PoseLandmarkType.leftElbow:
          lm(PoseLandmarkType.leftElbow, rotated(elbow)),
      PoseLandmarkType.leftWrist:
          lm(PoseLandmarkType.leftWrist, rotated(wrist)),
      PoseLandmarkType.leftHip: lm(PoseLandmarkType.leftHip, rotated(hipPoint)),
      PoseLandmarkType.leftKnee: lm(PoseLandmarkType.leftKnee, rotated(knee)),
      PoseLandmarkType.leftAnkle:
          lm(PoseLandmarkType.leftAnkle, rotated(ankle)),
      PoseLandmarkType.leftEar: lm(PoseLandmarkType.leftEar, rotated(ear)),
    },
  );
}

Offset _rotate(Offset v, double degrees) {
  final rad = degrees * math.pi / 180;
  final cosA = math.cos(rad);
  final sinA = math.sin(rad);
  return Offset(v.dx * cosA - v.dy * sinA, v.dx * sinA + v.dy * cosA);
}

void main() {
  group('idle / no pose', () {
    test('no poses -> Starting Position, neutral', () {
      final detector = PushUpFormDetector();
      final feedback = detector.evaluate(const []);
      expect(feedback.state, PushUpState.startingPosition);
      expect(feedback.color, PushUpFeedbackColor.neutral);
      expect(feedback.repCount, 0);
    });

    test('missing landmarks -> Starting Position', () {
      final detector = PushUpFormDetector();
      final pose = Pose(landmarks: {
        PoseLandmarkType.leftShoulder: PoseLandmark(
            type: PoseLandmarkType.leftShoulder,
            x: 0,
            y: 0,
            z: 0,
            likelihood: 0.9),
      });
      final feedback = detector.evaluate([pose]);
      expect(feedback.state, PushUpState.startingPosition);
    });

    test('brief dropout within grace period holds last feedback', () {
      final detector = PushUpFormDetector();
      final t0 = DateTime(2026);
      final first = detector.evaluate([buildPose()], now: t0);
      expect(first.state, PushUpState.correctStartingPosition);

      final dropped = detector
          .evaluate(const [], now: t0.add(const Duration(milliseconds: 200)));
      expect(dropped, same(first));
    });

    test('dropout beyond grace period resets to Starting Position', () {
      final detector = PushUpFormDetector();
      final t0 = DateTime(2026);
      detector.evaluate([buildPose()], now: t0);

      final dropped =
          detector.evaluate(const [], now: t0.add(const Duration(seconds: 2)));
      expect(dropped.state, PushUpState.startingPosition);
    });
  });

  group('correct starting position', () {
    test('straight body, good elbow angle -> Correct Starting Position, green',
        () {
      final detector = PushUpFormDetector();
      final feedback = detector.evaluate([buildPose()]);
      expect(feedback.state, PushUpState.correctStartingPosition);
      expect(feedback.color, PushUpFeedbackColor.success);
    });

    test(
        'holding correct position without moving eventually says No Movement Detected',
        () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      final first = detector.evaluate([buildPose()], now: t);
      expect(first.state, PushUpState.correctStartingPosition);

      t = t.add(const Duration(milliseconds: 500));
      final held = detector.evaluate([buildPose()], now: t);
      expect(held.state, PushUpState.correctFormMaintained);

      t = t.add(const Duration(seconds: 4));
      final stagnant = detector.evaluate([buildPose()], now: t);
      expect(stagnant.state, PushUpState.noMovementDetected);
      expect(stagnant.color, PushUpFeedbackColor.neutral);
    });
  });

  group('static form checks (priority order)', () {
    // Posture checks are (a) measured against a calibrated baseline from
    // the user's own neutral starting pose, and (b) debounced
    // (PushUpThresholds.minWarningPersistence, default 200ms) so a single
    // bad frame doesn't flip the message. So: calibrate on a straight
    // pose first (as a real rep would start), *then* hold the pose under
    // test across >200ms, and assert on the settled result.
    PushUpFeedback persist(Pose Function() pose, {int frames = 12}) {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      // First call is still phase "idle" (transitions to "ready" on this
      // same call) so doesn't count toward the calibration window — one
      // extra neutral frame beyond calibrationFrames to fully calibrate
      // before ever seeing the pose under test.
      for (var i = 0; i < 6; i++) {
        detector.evaluate([buildPose()], now: t);
        t = t.add(const Duration(milliseconds: 60));
      }
      PushUpFeedback feedback = detector.evaluate([pose()], now: t);
      for (var i = 0; i < frames; i++) {
        t = t.add(const Duration(milliseconds: 60));
        feedback = detector.evaluate([pose()], now: t);
      }
      return feedback;
    }

    test('severe sagging hips -> Body Too Low', () {
      final feedback = persist(() => buildPose(hipDeviationFrac: 0.35));
      expect(feedback.state, PushUpState.bodyTooLow);
      expect(feedback.color, PushUpFeedbackColor.warning);
    });

    test('severe piked hips -> Body Too High', () {
      final feedback = persist(() => buildPose(hipDeviationFrac: -0.35));
      expect(feedback.state, PushUpState.bodyTooHigh);
    });

    test(
        'mild hip deviation -> Back Not Straight (not severe enough for a direction)',
        () {
      final feedback = persist(() => buildPose(hipDeviationFrac: 0.08));
      expect(feedback.state, PushUpState.backNotStraight);
    });

    test('head dropped -> Head Too Low', () {
      final feedback = persist(() => buildPose(headDeviationFrac: 0.35));
      expect(feedback.state, PushUpState.headTooLow);
    });

    test('head lifted -> Head Too High', () {
      final feedback = persist(() => buildPose(headDeviationFrac: -0.35));
      expect(feedback.state, PushUpState.headTooHigh);
    });

    test('elbows flared -> Elbows Too Wide', () {
      final feedback = persist(() => buildPose(abductionAngleDeg: 70));
      expect(feedback.state, PushUpState.elbowsTooWide);
    });

    test('elbows tucked -> Elbows Too Close', () {
      final feedback = persist(() => buildPose(abductionAngleDeg: 10));
      expect(feedback.state, PushUpState.elbowsTooClose);
    });

    test('knees sagging off the hip-ankle line -> Wrong Body Alignment', () {
      final feedback = persist(() => buildPose(kneeDeviationFrac: 0.2));
      expect(feedback.state, PushUpState.wrongBodyAlignment);
    });

    test('hip issue outranks a simultaneous elbow issue', () {
      final feedback = persist(
          () => buildPose(hipDeviationFrac: 0.35, abductionAngleDeg: 70));
      expect(feedback.state, PushUpState.bodyTooLow);
    });

    test('head issue outranks a simultaneous elbow issue', () {
      final feedback = persist(
          () => buildPose(headDeviationFrac: 0.35, abductionAngleDeg: 70));
      expect(feedback.state, PushUpState.headTooLow);
    });

    test('a single noisy frame mid-descent does not flash a warning', () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      // Settle at the top, then descend normally...
      detector.evaluate([buildPose(elbowAngleDeg: 170)], now: t);
      t = t.add(const Duration(milliseconds: 60));
      detector.evaluate([buildPose(elbowAngleDeg: 140)], now: t);
      // ...one single frame reads a spurious hip blip (landmark jitter)...
      t = t.add(const Duration(milliseconds: 60));
      final blip = detector.evaluate(
        [buildPose(elbowAngleDeg: 130, hipDeviationFrac: 0.35)],
        now: t,
      );
      // ...then form is clean again immediately after.
      expect(blip.state, isNot(PushUpState.bodyTooLow));
    });
  });

  group('full rep cycle', () {
    test(
        'correct starting -> controlled descent -> correct depth -> controlled ascent -> top counts a rep',
        () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      const dt = Duration(milliseconds: 150);

      final states = <PushUpState>[];
      void step(double elbowAngle) {
        t = t.add(dt);
        states.add(detector
            .evaluate([buildPose(elbowAngleDeg: elbowAngle)], now: t).state);
      }

      // Settle at the top first.
      states.add(
          detector.evaluate([buildPose(elbowAngleDeg: 170)], now: t).state);
      // Controlled descent, ~13°/frame at 150ms -> well under the fast-movement
      // threshold. Elbow angle is EMA-smoothed internally, so a few repeated
      // frames at the target hold are needed for the smoothed value to
      // actually converge past a threshold (matches a real camera stream,
      // which sends many small-delta frames rather than one big jump).
      for (final angle in [160, 145, 130, 115, 100, 90, 90, 90, 90, 90]) {
        step(angle.toDouble());
      }
      // Controlled ascent.
      for (final angle in [115, 130, 145, 160, 175, 175, 175]) {
        step(angle.toDouble());
      }

      expect(states, contains(PushUpState.correctDownwardMovement));
      expect(states, contains(PushUpState.correctBottomPosition));
      expect(states, contains(PushUpState.correctUpwardMovement));
      expect(states, contains(PushUpState.correctPushUpCompleted));
      expect(detector.repCount, 1);
    });

    test(
        'reversing before reaching depth is Not Going Low Enough and does not count',
        () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      const dt = Duration(milliseconds: 150);
      final states = <PushUpState>[];

      void step(double elbowAngle) {
        t = t.add(dt);
        states.add(detector
            .evaluate([buildPose(elbowAngleDeg: elbowAngle)], now: t).state);
      }

      step(170);
      // Only dips to 130° (bottomElbowAngle is 100°) before reversing.
      for (final angle in [160, 145, 130, 145, 160, 175]) {
        step(angle.toDouble());
      }

      expect(states, contains(PushUpState.notGoingLowEnough));
      expect(states, contains(PushUpState.incompletePushUp));
      expect(detector.repCount, 0);
    });

    test('descending past the safe depth is Going Too Low and does not count',
        () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      const dt = Duration(milliseconds: 150);
      final states = <PushUpState>[];

      void step(double elbowAngle) {
        t = t.add(dt);
        states.add(detector
            .evaluate([buildPose(elbowAngleDeg: elbowAngle)], now: t).state);
      }

      step(170);
      for (final angle in [150, 120, 90, 60, 40, 40, 40, 40, 40]) {
        step(angle.toDouble());
      }
      for (final angle in [60, 90, 120, 150, 175, 175, 175]) {
        step(angle.toDouble());
      }

      expect(states, contains(PushUpState.goingTooLow));
      expect(states, contains(PushUpState.incompletePushUp));
      expect(detector.repCount, 0);
    });

    test(
        'a form issue during the rep marks it incomplete even if depth was reached',
        () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      const dt = Duration(milliseconds: 150);

      void step(double elbowAngle, {double hipDeviationFrac = 0}) {
        t = t.add(dt);
        detector.evaluate(
          [
            buildPose(
                elbowAngleDeg: elbowAngle, hipDeviationFrac: hipDeviationFrac)
          ],
          now: t,
        );
      }

      step(170);
      step(140);
      step(100, hipDeviationFrac: 0.35); // sagging mid-rep
      step(90);
      final last = <PushUpState>[];
      for (final angle in [
        100.0,
        120.0,
        140.0,
        160.0,
        175.0,
        175.0,
        175.0,
        175.0
      ]) {
        t = t.add(dt);
        last.add(
            detector.evaluate([buildPose(elbowAngleDeg: angle)], now: t).state);
      }

      expect(last, contains(PushUpState.incompletePushUp));
      expect(detector.repCount, 0);
    });
  });

  group('calibration robustness', () {
    test(
        'an unstable window (settling into position) does not lock in a bad baseline',
        () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      void step(Pose pose) {
        detector.evaluate([pose], now: t);
        t = t.add(const Duration(milliseconds: 60));
      }

      // Drifts through several different head positions while "settling
      // in" — an unstable window that should never lock in as neutral —
      // then holds a genuinely straight position long enough to
      // calibrate against *that* instead.
      step(buildPose(headDeviationFrac: 0.3));
      step(buildPose(headDeviationFrac: 0.1));
      step(buildPose(headDeviationFrac: -0.2));
      step(buildPose());
      step(buildPose());
      step(buildPose());
      step(buildPose());
      step(buildPose());
      final settled = detector.evaluate([buildPose()], now: t);

      expect(settled.debug!.calibrated, isTrue);
      expect(settled.debug!.headDeviation.abs(), lessThan(0.05));
    });
  });

  group('body-orientation gate', () {
    test(
        'standing up mid-set (body rotated away from calibrated push-up angle) stops rep tracking',
        () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      const dt = Duration(milliseconds: 150);

      // Calibrate on a genuine push-up top position.
      for (var i = 0; i < 6; i++) {
        detector.evaluate([buildPose()], now: t);
        t = t.add(dt);
      }

      // Now "stand up": body line rotates 90°, but elbow keeps bending
      // through the exact same range a real descent would (e.g. a bicep
      // curl) — this used to be read as a legitimate rep. The rotation
      // signal is itself EMA-smoothed, so the gate takes a frame or two
      // to catch up — check it settles, not that it's instant.
      final states = <PushUpState>[];
      for (final angle in [150.0, 120.0, 90.0, 90.0, 90.0, 130.0, 160.0]) {
        states.add(
          detector.evaluate([buildPose(elbowAngleDeg: angle, bodyAngleDeg: 90)],
              now: t).state,
        );
        t = t.add(dt);
      }

      expect(states.skip(2), everyElement(PushUpState.startingPosition));
      expect(detector.repCount, 0);
    });

    test(
        'returning to the calibrated orientation resumes tracking without recalibrating',
        () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      const dt = Duration(milliseconds: 150);

      for (var i = 0; i < 6; i++) {
        detector.evaluate([buildPose()], now: t);
        t = t.add(dt);
      }

      // Stand up briefly (a few frames so the smoothed rotation signal
      // actually crosses the gate threshold)...
      for (var i = 0; i < 3; i++) {
        detector.evaluate([buildPose(bodyAngleDeg: 90)], now: t);
        t = t.add(dt);
      }

      // ...then back into the push-up position — should be recognized as
      // "correct starting position" immediately, not stuck waiting to
      // recalibrate.
      final back = detector.evaluate([buildPose()], now: t);
      expect(back.state, PushUpState.correctStartingPosition);
    });
  });

  group('reset', () {
    test('zeroes rep count and returns to idle', () {
      final detector = PushUpFormDetector();
      var t = DateTime(2026);
      const dt = Duration(milliseconds: 150);

      void step(double elbowAngle) {
        t = t.add(dt);
        detector.evaluate([buildPose(elbowAngleDeg: elbowAngle)], now: t);
      }

      step(170);
      for (final angle in [150, 120, 100, 90, 90, 90, 90, 90]) {
        step(angle.toDouble());
      }
      for (final angle in [120, 150, 175, 175, 175, 175]) {
        step(angle.toDouble());
      }
      expect(detector.repCount, 1);

      detector.reset();
      expect(detector.repCount, 0);
      final feedback = detector.evaluate(const []);
      expect(feedback.state, PushUpState.startingPosition);
    });
  });

  group('static lookups', () {
    test('messageFor / colorFor match the evaluated feedback', () {
      expect(
        PushUpFormDetector.messageFor(PushUpState.correctPushUpCompleted),
        'Perfect push-up! Keep going.',
      );
      expect(
        PushUpFormDetector.colorFor(PushUpState.goingTooLow),
        PushUpFeedbackColor.warning,
      );
    });
  });
}
