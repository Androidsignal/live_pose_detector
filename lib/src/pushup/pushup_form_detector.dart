import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../utils/pose_math.dart';
import 'pushup_thresholds.dart';
import 'pushup_types.dart';

/// Stateful push-up form checker + rep counter, built entirely on top of
/// this package's public landmark API — feed it every frame's [Pose] list
/// (e.g. from `CameraPoseView.onPosesDetected`) and it returns one
/// [PushUpFeedback] per frame: a single message, a [PushUpFeedbackColor],
/// and the running rep count.
///
/// ## Why per-frame landmarks alone aren't accurate enough
///
/// A single 2D camera measuring a straight body line against fixed
/// absolute thresholds is fragile in practice: camera angle, body
/// proportions, and even which side (left/right) got picked each frame
/// all shift what "straight" reads as, and landmark noise spikes exactly
/// when the body is moving fastest — mid-rep. Three things correct for
/// that:
///
/// - **Auto-calibration** ([PushUpThresholds.calibrationFrames]): the
///   first few frames spent holding the *top* position establish this
///   user's neutral hip/head/knee baseline, and every check afterward
///   measures deviation from that baseline instead of an assumed
///   absolute zero. Gated to the top position specifically — a sample
///   taken mid-setup or already mid-rep would bake that into the
///   baseline for the whole set.
/// - **Depth-adaptive tolerance** ([PushUpThresholds.depthToleranceExpansion]):
///   a single side-on 2D camera reads more hip/head deviation than
///   actually exists as the torso foreshortens with a bent elbow —
///   tolerance widens smoothly from the top to the bottom of a rep so a
///   correct deep rep doesn't read as worse form for being deeper.
/// - **Debounce** ([PushUpThresholds.minWarningPersistence]): a posture
///   issue (back/head/elbow/knee) has to be the top-priority issue for a
///   sustained stretch before it's actually shown, so a single noisy
///   frame mid-descent doesn't flash a warning during otherwise-correct
///   movement. Depth/tempo/rep-summary feedback stays instant — those are
///   discrete events, not sustained conditions.
/// - **Confidence gating** ([PushUpThresholds.minLandmarkConfidence]): a
///   side with unreliable landmarks (occlusion, motion blur) is treated
///   as "no person" rather than judged.
///
/// [PushUpFeedback.debug] exposes the raw numbers behind every judgment —
/// use it to tune [PushUpThresholds] against a real camera setup instead
/// of guessing.
///
/// ## Priority
///
/// Multiple things can be wrong at once (elbows flared *and* hips
/// sagging), but only one message is ever shown — [_priorityOrder] picks
/// the most important, safety-first: spine (back straightness) > neck >
/// elbows > depth safety > tempo > insufficient depth > leg alignment >
/// rep summary. Positive/neutral messages only appear when nothing on
/// that list is active (or active but not yet debounced-confirmed).
///
/// ## Rep counting
///
/// A rep only counts on **correct starting position → controlled descent
/// → correct depth → controlled ascent → correct top position**, with no
/// form issue anywhere in between. Any issue along the way (bad form, too
/// fast, insufficient depth) marks the rep invalid — it still finishes the
/// phase cycle, but reports "Incomplete Push-Up" instead of incrementing
/// the count.
///
/// One instance per exercise set — call [reset] to zero the rep count,
/// phase, and calibration between sets.
class PushUpFormDetector {
  PushUpFormDetector({PushUpThresholds thresholds = const PushUpThresholds()})
      : _t = thresholds;

  final PushUpThresholds _t;

  // Smoothing / direction-detection constants — implementation detail, not
  // exposed as thresholds (they tune noise rejection, not form judgment).
  static const double _smoothingFactor = 0.4;
  static const double _directionEpsilonDegrees = 2.0;

  PushUpPhase _phase = PushUpPhase.idle;
  double? _smoothedElbowAngle;
  double _minElbowAngleThisRep = 180;
  bool _reachedValidDepth = false;
  bool _repValid = true;
  bool _freshReadyEntry = false;
  int _repCount = 0;

  final _DeviationTracker _hipTracker = _DeviationTracker();
  final _DeviationTracker _headTracker = _DeviationTracker();
  final _DeviationTracker _kneeTracker = _DeviationTracker();
  final _DeviationTracker _bodyAngleTracker = _DeviationTracker();
  double? _smoothedAbduction;
  double? _unwrappedBodyAngle;

  PushUpState? _pendingWarning;
  DateTime? _pendingWarningSince;

  DateTime? _prevFrameTime;
  DateTime? _lastMovementTime;
  DateTime? _lastValidFrameTime;
  PushUpFeedback? _lastFeedback;

  /// Priority order (most to least important) — see class doc.
  static const List<PushUpState> _priorityOrder = [
    PushUpState.backNotStraight,
    PushUpState.bodyTooHigh,
    PushUpState.bodyTooLow,
    PushUpState.headTooLow,
    PushUpState.headTooHigh,
    PushUpState.elbowsTooWide,
    PushUpState.elbowsTooClose,
    PushUpState.goingTooLow,
    PushUpState.movementTooFast,
    PushUpState.notGoingLowEnough,
    PushUpState.wrongBodyAlignment,
    PushUpState.incompletePushUp,
  ];

  /// Posture checks (back/head/elbow/knee line-and-angle checks) that get
  /// debounced via [PushUpThresholds.minWarningPersistence] — noisiest
  /// mid-rep, and a false flash on any one of these is exactly the
  /// "correct form still shows a warning" complaint this exists to fix.
  /// Depth/tempo/rep-summary states are discrete events and always shown
  /// immediately.
  static const Set<PushUpState> _debouncedStates = {
    PushUpState.backNotStraight,
    PushUpState.bodyTooHigh,
    PushUpState.bodyTooLow,
    PushUpState.headTooLow,
    PushUpState.headTooHigh,
    PushUpState.elbowsTooWide,
    PushUpState.elbowsTooClose,
    PushUpState.wrongBodyAlignment,
  };

  static const Map<PushUpState, String> _messages = {
    PushUpState.startingPosition: 'Get into the push-up position.',
    PushUpState.correctStartingPosition:
        "Great! You're in the correct position.",
    PushUpState.bodyTooHigh: 'Lower your hips and keep your body straight.',
    PushUpState.bodyTooLow:
        'Raise your hips slightly and keep your body aligned.',
    PushUpState.headTooLow: 'Keep your head aligned with your body.',
    PushUpState.headTooHigh:
        'Keep your neck neutral and look slightly forward.',
    PushUpState.elbowsTooWide: 'Keep your elbows closer to your body.',
    PushUpState.elbowsTooClose:
        'Adjust your elbows slightly outward for a comfortable position.',
    PushUpState.backNotStraight:
        'Keep your back straight and maintain a strong core.',
    PushUpState.notGoingLowEnough:
        'Lower your body further to complete the push-up.',
    PushUpState.goingTooLow:
        "Don't lower too far. Maintain a controlled range of motion.",
    PushUpState.correctDownwardMovement: 'Good! Keep lowering with control.',
    PushUpState.correctBottomPosition: 'Great depth! Now push back up.',
    PushUpState.correctUpwardMovement: 'Good push! Keep your body straight.',
    PushUpState.correctPushUpCompleted: 'Perfect push-up! Keep going.',
    PushUpState.movementTooFast:
        'Slow down and perform the movement with control.',
    PushUpState.incompletePushUp:
        'Complete the full movement from top to bottom.',
    PushUpState.wrongBodyAlignment:
        'Align your head, shoulders, hips, and legs.',
    PushUpState.correctFormMaintained: 'Excellent form! Keep it up.',
    PushUpState.noMovementDetected: "Start your push-up when you're ready.",
  };

  static const Map<PushUpState, PushUpFeedbackColor> _colors = {
    PushUpState.startingPosition: PushUpFeedbackColor.neutral,
    PushUpState.correctStartingPosition: PushUpFeedbackColor.success,
    PushUpState.bodyTooHigh: PushUpFeedbackColor.warning,
    PushUpState.bodyTooLow: PushUpFeedbackColor.warning,
    PushUpState.headTooLow: PushUpFeedbackColor.warning,
    PushUpState.headTooHigh: PushUpFeedbackColor.warning,
    PushUpState.elbowsTooWide: PushUpFeedbackColor.warning,
    PushUpState.elbowsTooClose: PushUpFeedbackColor.warning,
    PushUpState.backNotStraight: PushUpFeedbackColor.warning,
    PushUpState.notGoingLowEnough: PushUpFeedbackColor.warning,
    PushUpState.goingTooLow: PushUpFeedbackColor.warning,
    PushUpState.correctDownwardMovement: PushUpFeedbackColor.success,
    PushUpState.correctBottomPosition: PushUpFeedbackColor.success,
    PushUpState.correctUpwardMovement: PushUpFeedbackColor.success,
    PushUpState.correctPushUpCompleted: PushUpFeedbackColor.success,
    PushUpState.movementTooFast: PushUpFeedbackColor.warning,
    PushUpState.incompletePushUp: PushUpFeedbackColor.warning,
    PushUpState.wrongBodyAlignment: PushUpFeedbackColor.warning,
    PushUpState.correctFormMaintained: PushUpFeedbackColor.success,
    PushUpState.noMovementDetected: PushUpFeedbackColor.neutral,
  };

  /// The fixed message for [state] — exposed for host apps that want to
  /// build their own [PushUpState] → UI mapping without re-running
  /// [evaluate].
  static String messageFor(PushUpState state) => _messages[state]!;

  /// The fixed color bucket for [state].
  static PushUpFeedbackColor colorFor(PushUpState state) => _colors[state]!;

  /// Reps completed so far.
  int get repCount => _repCount;

  /// Zeroes the rep count, rep-cycle phase, and hip/head/knee calibration
  /// — call between sets. Does not change [PushUpThresholds].
  void reset() {
    _phase = PushUpPhase.idle;
    _smoothedElbowAngle = null;
    _minElbowAngleThisRep = 180;
    _reachedValidDepth = false;
    _repValid = true;
    _freshReadyEntry = false;
    _repCount = 0;
    _hipTracker.reset();
    _headTracker.reset();
    _kneeTracker.reset();
    _bodyAngleTracker.reset();
    _smoothedAbduction = null;
    _unwrappedBodyAngle = null;
    _pendingWarning = null;
    _pendingWarningSince = null;
    _prevFrameTime = null;
    _lastMovementTime = null;
    _lastValidFrameTime = null;
    _lastFeedback = null;
  }

  /// Evaluates one frame's poses. Call on every frame from
  /// `CameraPoseView.onPosesDetected`.
  ///
  /// [now] is for testability — defaults to [DateTime.now].
  PushUpFeedback evaluate(List<Pose> poses, {DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final side = poses.isEmpty ? null : _betterSide(poses.first.landmarks);

    if (side == null) {
      final lastValid = _lastValidFrameTime;
      final cached = _lastFeedback;
      if (lastValid != null &&
          cached != null &&
          timestamp.difference(lastValid) <= _t.poseLostGrace) {
        // Brief dropout (one occluded landmark, a missed frame) — hold the
        // last feedback instead of flickering back to "Starting Position".
        return cached;
      }
      _phase = PushUpPhase.idle;
      _smoothedElbowAngle = null;
      _minElbowAngleThisRep = 180;
      _reachedValidDepth = false;
      _repValid = true;
      _freshReadyEntry = false;
      return _emit(PushUpState.startingPosition, timestamp, debug: null);
    }

    _lastValidFrameTime = timestamp;

    // Elbow angle first — it drives both the depth-perspective tolerance
    // below and the rep phase machine.
    final rawElbowAngle =
        angleBetweenLandmarks(side.shoulder, side.elbow, side.wrist);
    // Deep in a rep, a single side-on 2D camera reads more hip/head
    // deviation than actually exists — the torso foreshortens as the
    // elbow bends. Scale tolerance up smoothly from the top (0) to full
    // depth (depthToleranceExpansion), using *last* frame's smoothed
    // angle so this doesn't depend on this frame's phase update yet.
    final elbowForTolerance = _smoothedElbowAngle ?? rawElbowAngle;
    final depthFactor = ((_t.topElbowAngle - elbowForTolerance) /
            (_t.topElbowAngle - _t.bottomElbowAngle))
        .clamp(0.0, 1.0);
    final toleranceScale = 1 + depthFactor * _t.depthToleranceExpansion;

    // Smoothed deviations next. Calibration only samples while at the top
    // (_phase is still last frame's value here, before _advancePhase runs
    // below) — locking a baseline mid-rep or mid-setup is exactly what
    // produces wildly-off readings for the rest of the set.
    final calibrating = _phase == PushUpPhase.ready;

    // Body-orientation gate: elbow angle alone can't tell a prone push-up
    // from someone standing and bending their arm (a bicep curl, an
    // "arm position" demo) — both bend the elbow through the same range.
    // What *does* distinguish them is the shoulder→ankle line's own
    // angle: it barely changes through a real push-up rep, but rotates
    // sharply if the person stands up or the camera cuts to an unrelated
    // clip. Calibrate that angle alongside the deviations above, then
    // refuse to run rep logic at all once it's drifted too far from the
    // calibrated push-up orientation.
    final rawBodyAngle = math.atan2(
            side.ankle.y - side.shoulder.y, side.ankle.x - side.shoulder.x) *
        180 /
        math.pi;
    final unwrappedBodyAngle = _unwrap(rawBodyAngle, _unwrappedBodyAngle);
    _unwrappedBodyAngle = unwrappedBodyAngle;
    final smoothedBodyAngle =
        _bodyAngleTracker.smooth(unwrappedBodyAngle, _smoothingFactor);
    if (calibrating) {
      _bodyAngleTracker.maybeCalibrate(
        smoothedBodyAngle,
        _t.calibrationFrames,
        _t.calibrationMaxSpreadDegrees,
      );
    }
    final bodyRotation = _bodyAngleTracker.deviation(smoothedBodyAngle);

    if (_bodyAngleTracker.calibrated &&
        bodyRotation.abs() > _t.maxBodyRotationDegrees) {
      // Body has rotated away from the calibrated push-up orientation —
      // whatever's happening now isn't a push-up. Drop any in-progress
      // rep (it can't be valid) but keep the calibration: if the person
      // returns to position, resume without recalibrating from scratch.
      _phase = PushUpPhase.idle;
      _smoothedElbowAngle = null;
      _minElbowAngleThisRep = 180;
      _reachedValidDepth = false;
      _repValid = true;
      _freshReadyEntry = false;
      return _emit(PushUpState.startingPosition, timestamp, debug: null);
    }

    final rawHipDev = _signed(
        signedLandmarkLineDeviation(side.shoulder, side.ankle, side.hip));
    final smoothedHipDev = _hipTracker.smooth(rawHipDev, _smoothingFactor);
    if (calibrating) {
      _hipTracker.maybeCalibrate(
          smoothedHipDev, _t.calibrationFrames, _t.calibrationMaxSpread);
    }
    final hipDeviation = _hipTracker.deviation(smoothedHipDev);

    final rawHeadDev =
        _signed(signedLandmarkLineDeviation(side.shoulder, side.hip, side.ear));
    final smoothedHeadDev = _headTracker.smooth(rawHeadDev, _smoothingFactor);
    if (calibrating) {
      _headTracker.maybeCalibrate(
          smoothedHeadDev, _t.calibrationFrames, _t.calibrationMaxSpread);
    }
    final headDeviation = _headTracker.deviation(smoothedHeadDev);

    final rawKneeDev =
        _signed(signedLandmarkLineDeviation(side.hip, side.ankle, side.knee));
    final smoothedKneeDev = _kneeTracker.smooth(rawKneeDev, _smoothingFactor);
    if (calibrating) {
      _kneeTracker.maybeCalibrate(
          smoothedKneeDev, _t.calibrationFrames, _t.calibrationMaxSpread);
    }
    final kneeDeviation = _kneeTracker.deviation(smoothedKneeDev);

    final rawAbduction =
        angleBetweenLandmarks(side.elbow, side.shoulder, side.hip);
    final prevAbduction = _smoothedAbduction;
    final abductionAngle = prevAbduction == null
        ? rawAbduction
        : prevAbduction + (rawAbduction - prevAbduction) * _smoothingFactor;
    _smoothedAbduction = abductionAngle;

    final hip = _classifyHip(hipDeviation, toleranceScale);
    final head =
        hip == null ? _classifyHead(headDeviation, toleranceScale) : null;
    final elbow =
        (hip == null && head == null) ? _classifyElbow(abductionAngle) : null;
    final formOk = hip == null && head == null && elbow == null;

    final phaseResult = _advancePhase(rawElbowAngle, timestamp, formOk: formOk);
    final knee = _classifyKnee(kneeDeviation, toleranceScale);

    final candidates = <PushUpState>[
      if (hip != null) hip,
      if (head != null) head,
      if (elbow != null) elbow,
      if (phaseResult.tooLow) PushUpState.goingTooLow,
      if (phaseResult.tooFast) PushUpState.movementTooFast,
      if (phaseResult.notLowEnough) PushUpState.notGoingLowEnough,
      if (knee != null) knee,
      if (phaseResult.incomplete) PushUpState.incompletePushUp,
      phaseResult.positive,
    ];
    candidates.sort((a, b) => _priority(a).compareTo(_priority(b)));
    final topCandidate = candidates.first;

    final chosen = _debounce(topCandidate, phaseResult.positive, timestamp);

    final debug = PushUpDebugInfo(
      elbowAngle: _smoothedElbowAngle ?? rawElbowAngle,
      abductionAngle: abductionAngle,
      hipDeviation: hipDeviation,
      headDeviation: headDeviation,
      kneeDeviation: kneeDeviation,
      calibrated: _hipTracker.calibrated,
    );
    return _emit(chosen, timestamp, debug: debug);
  }

  double _signed(double deviation) =>
      _t.invertBodyLineSign ? -deviation : deviation;

  /// Brings [raw] (degrees) within 180° of [previous] by adding/subtracting
  /// full turns, so EMA-smoothing an angle near the ±180° wraparound point
  /// doesn't produce a nonsense average (e.g. blending 179° and -179°
  /// should land near ±180°, not near 0°).
  double _unwrap(double raw, double? previous) {
    if (previous == null) return raw;
    var value = raw;
    while (value - previous > 180) {
      value -= 360;
    }
    while (value - previous < -180) {
      value += 360;
    }
    return value;
  }

  /// A [_debouncedStates] candidate only wins once it's been the
  /// top-priority pick continuously for [PushUpThresholds.minWarningPersistence]
  /// — until then, [fallback] (the phase's own positive/neutral message)
  /// is shown instead. Everything else (depth/tempo/rep-summary/positive)
  /// passes straight through.
  PushUpState _debounce(
      PushUpState topCandidate, PushUpState fallback, DateTime timestamp) {
    if (!_debouncedStates.contains(topCandidate)) {
      _pendingWarning = null;
      _pendingWarningSince = null;
      return topCandidate;
    }

    if (_pendingWarning != topCandidate) {
      _pendingWarning = topCandidate;
      _pendingWarningSince = timestamp;
    }
    final persisted =
        timestamp.difference(_pendingWarningSince!) >= _t.minWarningPersistence;
    return persisted ? topCandidate : fallback;
  }

  int _priority(PushUpState state) {
    final index = _priorityOrder.indexOf(state);
    return index == -1 ? _priorityOrder.length : index;
  }

  PushUpFeedback _emit(PushUpState state, DateTime timestamp,
      {required PushUpDebugInfo? debug}) {
    final feedback = PushUpFeedback(
      state: state,
      message: _messages[state]!,
      color: _colors[state]!,
      repCount: _repCount,
      phase: _phase,
      debug: debug,
    );
    _lastFeedback = feedback;
    return feedback;
  }

  // --- Static form checks (priority tiers 1-3 + leg alignment) ----------
  // All read pre-smoothed, baseline-calibrated deviations — see evaluate().

  PushUpState? _classifyHip(double deviation, double toleranceScale) {
    final magnitude = deviation.abs();
    if (magnitude <= _t.hipMildDeviation * toleranceScale) return null;
    if (magnitude <= _t.hipSevereDeviation * toleranceScale) {
      return PushUpState.backNotStraight;
    }
    return deviation > 0 ? PushUpState.bodyTooLow : PushUpState.bodyTooHigh;
  }

  PushUpState? _classifyHead(double deviation, double toleranceScale) {
    if (deviation.abs() <= _t.headDeviation * toleranceScale) return null;
    return deviation > 0 ? PushUpState.headTooLow : PushUpState.headTooHigh;
  }

  PushUpState? _classifyElbow(double abductionAngle) {
    if (abductionAngle < _t.elbowAbductionMin) {
      return PushUpState.elbowsTooClose;
    }
    if (abductionAngle > _t.elbowAbductionMax) return PushUpState.elbowsTooWide;
    return null;
  }

  PushUpState? _classifyKnee(double deviation, double toleranceScale) {
    if (deviation.abs() <= _t.kneeAlignmentDeviation * toleranceScale) {
      return null;
    }
    return PushUpState.wrongBodyAlignment;
  }

  // --- Rep-cycle phase machine -------------------------------------------

  _PhaseResult _advancePhase(double rawAngle, DateTime now,
      {required bool formOk}) {
    final previousSmoothed = _smoothedElbowAngle;
    final smoothed = previousSmoothed == null
        ? rawAngle
        : previousSmoothed + (rawAngle - previousSmoothed) * _smoothingFactor;

    final prevTime = _prevFrameTime;
    final dtSeconds =
        prevTime == null ? 0.0 : now.difference(prevTime).inMicroseconds / 1e6;
    final delta = previousSmoothed == null ? 0.0 : smoothed - previousSmoothed;
    final speed = dtSeconds > 0 ? delta.abs() / dtSeconds : 0.0;
    final direction =
        delta.abs() < _directionEpsilonDegrees ? 0 : (delta < 0 ? -1 : 1);

    if (direction != 0) _lastMovementTime = now;
    _lastMovementTime ??= now;

    var tooLow = false;
    var tooFast = false;
    var notLowEnough = false;
    var incomplete = false;
    PushUpState positive = PushUpState.startingPosition;

    switch (_phase) {
      case PushUpPhase.idle:
        if (rawAngle >= _t.topElbowAngle) {
          _phase = PushUpPhase.ready;
          _freshReadyEntry =
              false; // announced immediately below, not next frame
          _lastMovementTime = now;
          positive = PushUpState.correctStartingPosition;
        } else {
          positive = PushUpState.startingPosition;
        }

      case PushUpPhase.ready:
        if (direction == -1 &&
            smoothed < _t.topElbowAngle - _directionEpsilonDegrees) {
          _phase = PushUpPhase.descending;
          _minElbowAngleThisRep = smoothed;
          _reachedValidDepth = false;
          _repValid = true;
          positive = PushUpState.correctDownwardMovement;
        } else if (_freshReadyEntry) {
          positive = PushUpState.correctStartingPosition;
          _freshReadyEntry = false;
        } else if (now.difference(_lastMovementTime!) > _t.stagnantHold) {
          positive = PushUpState.noMovementDetected;
        } else {
          positive = PushUpState.correctFormMaintained;
        }

      case PushUpPhase.descending:
        _minElbowAngleThisRep = math.min(_minElbowAngleThisRep, smoothed);
        if (!formOk) _repValid = false;
        if (speed > _t.fastMovementDegreesPerSecond) {
          tooFast = true;
          _repValid = false;
        }
        if (smoothed <= _t.tooLowElbowAngle) {
          tooLow = true;
          _repValid = false;
          _phase = PushUpPhase.bottom;
        } else if (smoothed <= _t.bottomElbowAngle) {
          _reachedValidDepth = true;
          _phase = PushUpPhase.bottom;
          positive = PushUpState.correctBottomPosition;
        } else if (direction == 1) {
          // Reversed toward the top before ever reaching target depth.
          notLowEnough = true;
          _repValid = false;
          _phase = PushUpPhase.ascending;
        } else {
          positive = PushUpState.correctDownwardMovement;
        }

      case PushUpPhase.bottom:
        _minElbowAngleThisRep = math.min(_minElbowAngleThisRep, smoothed);
        if (!formOk) _repValid = false;
        if (smoothed <= _t.tooLowElbowAngle) {
          tooLow = true;
          _repValid = false;
        } else {
          positive = PushUpState.correctBottomPosition;
        }
        if (direction == 1) {
          _phase = PushUpPhase.ascending;
        }

      case PushUpPhase.ascending:
        if (!formOk) _repValid = false;
        if (speed > _t.fastMovementDegreesPerSecond) {
          tooFast = true;
          _repValid = false;
        }
        if (smoothed >= _t.topElbowAngle) {
          if (!_reachedValidDepth || !_repValid) {
            incomplete = true;
          } else {
            _repCount++;
            positive = PushUpState.correctPushUpCompleted;
          }
          _phase = PushUpPhase.ready;
          _freshReadyEntry = true;
          _lastMovementTime = now;
        } else if (direction == -1) {
          // Dipped back down mid-ascent — resume descent tracking.
          _phase = PushUpPhase.descending;
          positive = PushUpState.correctDownwardMovement;
        } else {
          positive = PushUpState.correctUpwardMovement;
        }
    }

    _smoothedElbowAngle = smoothed;
    _prevFrameTime = now;

    return _PhaseResult(
      tooLow: tooLow,
      tooFast: tooFast,
      notLowEnough: notLowEnough,
      incomplete: incomplete,
      positive: positive,
    );
  }

  // --- Landmark side selection --------------------------------------------

  _SideLandmarks? _betterSide(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final left = _sideLandmarks(landmarks, isLeft: true);
    final right = _sideLandmarks(landmarks, isLeft: false);
    if (left == null) return right;
    if (right == null) return left;
    return left.confidence >= right.confidence ? left : right;
  }

  _SideLandmarks? _sideLandmarks(
    Map<PoseLandmarkType, PoseLandmark> landmarks, {
    required bool isLeft,
  }) {
    PoseLandmark? get(PoseLandmarkType left, PoseLandmarkType right) =>
        landmarks[isLeft ? left : right];

    final shoulder =
        get(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    final elbow = get(PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow);
    final wrist = get(PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist);
    final hip = get(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
    final knee = get(PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee);
    final ankle = get(PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle);
    final ear = get(PoseLandmarkType.leftEar, PoseLandmarkType.rightEar);

    if (shoulder == null ||
        elbow == null ||
        wrist == null ||
        hip == null ||
        knee == null ||
        ankle == null ||
        ear == null) {
      return null;
    }

    final side = _SideLandmarks(
      shoulder: shoulder,
      elbow: elbow,
      wrist: wrist,
      hip: hip,
      knee: knee,
      ankle: ankle,
      ear: ear,
    );
    // An unreliable side (occlusion, motion blur — common mid-rep) is
    // worse than no side: judging form off noisy landmarks is exactly
    // what produces spurious warnings.
    return side.confidence >= _t.minLandmarkConfidence ? side : null;
  }
}

class _PhaseResult {
  const _PhaseResult({
    required this.tooLow,
    required this.tooFast,
    required this.notLowEnough,
    required this.incomplete,
    required this.positive,
  });

  final bool tooLow;
  final bool tooFast;
  final bool notLowEnough;
  final bool incomplete;
  final PushUpState positive;
}

/// EMA-smooths a raw per-frame signal, then averages [calibrationFrames]
/// smoothed samples — collected only while the caller says it's safe to
/// (see [PushUpFormDetector.evaluate]'s `calibrating` gate) — into a
/// baseline that every later reading is measured against. See
/// [PushUpFormDetector]'s class doc.
class _DeviationTracker {
  double? _smoothed;
  double _baseline = 0;
  bool calibrated = false;
  final List<double> _samples = [];

  /// Always runs, every frame, regardless of calibration state.
  double smooth(double raw, double smoothingFactor) {
    final prev = _smoothed;
    final smoothed = prev == null ? raw : prev + (raw - prev) * smoothingFactor;
    _smoothed = smoothed;
    return smoothed;
  }

  /// Call only on frames the caller has judged trustworthy for
  /// calibration (e.g. holding the top position) — a sample taken
  /// mid-rep or mid-setup poisons the baseline for the rest of the set.
  ///
  /// Requires [calibrationFrames] *consecutive* samples within
  /// [maxSpread] of each other, not just the first [calibrationFrames]
  /// chronologically — a sample that breaks the streak (still settling
  /// into position, camera shake, a cut to a different angle) restarts
  /// the window instead of getting averaged in. Locking a baseline off an
  /// unstable window is exactly what produces a systematic offset in
  /// every later reading.
  void maybeCalibrate(
      double smoothedValue, int calibrationFrames, double maxSpread) {
    if (calibrated) return;
    _samples.add(smoothedValue);
    if (_samples.length > 1) {
      final minV = _samples.reduce(math.min);
      final maxV = _samples.reduce(math.max);
      if (maxV - minV > maxSpread) {
        _samples
          ..clear()
          ..add(smoothedValue);
      }
    }
    if (_samples.length >= calibrationFrames) {
      _baseline = _samples.reduce((a, b) => a + b) / _samples.length;
      calibrated = true;
    }
  }

  double deviation(double smoothedValue) => smoothedValue - _baseline;

  void reset() {
    _smoothed = null;
    _baseline = 0;
    calibrated = false;
    _samples.clear();
  }
}

class _SideLandmarks {
  const _SideLandmarks({
    required this.shoulder,
    required this.elbow,
    required this.wrist,
    required this.hip,
    required this.knee,
    required this.ankle,
    required this.ear,
  });

  final PoseLandmark shoulder;
  final PoseLandmark elbow;
  final PoseLandmark wrist;
  final PoseLandmark hip;
  final PoseLandmark knee;
  final PoseLandmark ankle;
  final PoseLandmark ear;

  double get confidence =>
      (shoulder.likelihood +
          elbow.likelihood +
          wrist.likelihood +
          hip.likelihood +
          knee.likelihood +
          ankle.likelihood +
          ear.likelihood) /
      7;
}
