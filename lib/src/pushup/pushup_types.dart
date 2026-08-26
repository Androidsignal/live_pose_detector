import 'package:flutter/foundation.dart';

/// Color bucket for a [PushUpFeedback] — maps 1:1 to how the host app
/// should render it (e.g. green/amber/gray), without this package
/// depending on `package:flutter/material.dart` for actual [Color] values.
enum PushUpFeedbackColor {
  /// Nothing to correct and nothing to celebrate yet — waiting for the
  /// user to get into position or start moving.
  neutral,

  /// Correct posture or movement — show this as green (or your app's
  /// equivalent "good" color).
  success,

  /// Something needs correcting — show this as your app's warning color.
  warning,
}

/// Every distinguishable moment [PushUpFormDetector] reports, in the exact
/// set the host app's spec calls for. Each has a fixed message and
/// [PushUpFeedbackColor] — see [PushUpFormDetector.messageFor] /
/// [PushUpFormDetector.colorFor].
enum PushUpState {
  /// No person / not enough landmarks visible yet.
  startingPosition,

  /// Just settled into a correct top/plank position.
  correctStartingPosition,

  /// Hips sagging low enough to be the dominant issue (severe tier of the
  /// shoulder→hip→ankle line check).
  bodyTooHigh,

  /// Hips piked/lifted enough to be the dominant issue (severe tier,
  /// opposite direction of [bodyTooHigh]).
  bodyTooLow,

  /// Head/neck dropped off the body line (severe tier of the
  /// hip→shoulder→ear check).
  headTooLow,

  /// Head/neck lifted off the body line, opposite direction of
  /// [headTooLow].
  headTooHigh,

  /// Elbow-to-torso abduction angle above the comfortable range.
  elbowsTooWide,

  /// Elbow-to-torso abduction angle below the comfortable range.
  elbowsTooClose,

  /// Mild hip-line deviation — not severe enough to call out a direction,
  /// just "not straight".
  backNotStraight,

  /// Reversed back toward the top before ever reaching target depth.
  notGoingLowEnough,

  /// Descended past a safe/target depth.
  goingTooLow,

  /// Descending, in target depth range, no active issue.
  correctDownwardMovement,

  /// Holding at target depth, no active issue.
  correctBottomPosition,

  /// Ascending, no active issue.
  correctUpwardMovement,

  /// Just finished a rep that passed every check throughout — this is the
  /// only state that increments the rep count.
  correctPushUpCompleted,

  /// Elbow angle changed faster than a controlled rep should.
  movementTooFast,

  /// Reached the top again without a valid rep (bad depth, form issue, or
  /// too fast somewhere along the way) — not counted.
  incompletePushUp,

  /// Knees have drifted off the hip→ankle line (legs not straight) — a
  /// body-alignment issue distinct from the hip/head/elbow checks.
  wrongBodyAlignment,

  /// Holding a correct top position, actively (recently moved).
  correctFormMaintained,

  /// Holding a correct top position, but stationary long enough that the
  /// user probably needs a nudge to start.
  noMovementDetected,
}

/// One frame's push-up feedback: which [PushUpState] fired, its message
/// and [PushUpFeedbackColor], and the rep count so far.
@immutable
class PushUpFeedback {
  const PushUpFeedback({
    required this.state,
    required this.message,
    required this.color,
    required this.repCount,
    required this.phase,
    this.debug,
  });

  final PushUpState state;
  final String message;
  final PushUpFeedbackColor color;

  /// Completed reps — only [PushUpState.correctPushUpCompleted] increments
  /// this.
  final int repCount;

  /// Which part of the rep cycle the detector currently thinks the user is
  /// in. Informational — e.g. for a custom progress indicator; the
  /// [message]/[color] already fold this in.
  final PushUpPhase phase;

  /// Raw measurements behind this frame's judgment — `null` when no
  /// person was detected. Not needed for basic use; read this when tuning
  /// [PushUpThresholds] against a real camera setup (log it, or render it
  /// in a debug overlay) instead of guessing why a threshold does or
  /// doesn't fire.
  final PushUpDebugInfo? debug;

  @override
  String toString() =>
      'PushUpFeedback($state, "$message", $color, phase: $phase, reps: $repCount)';
}

/// Raw per-frame measurements behind a [PushUpFeedback] — see
/// [PushUpFeedback.debug].
@immutable
class PushUpDebugInfo {
  const PushUpDebugInfo({
    required this.elbowAngle,
    required this.abductionAngle,
    required this.hipDeviation,
    required this.headDeviation,
    required this.kneeDeviation,
    required this.calibrated,
  });

  /// Smoothed shoulder-elbow-wrist angle (degrees) driving the rep phase.
  final double elbowAngle;

  /// Smoothed elbow-shoulder-hip abduction angle (degrees).
  final double abductionAngle;

  /// Smoothed, baseline-corrected hip-line deviation — compare against
  /// [PushUpThresholds.hipMildDeviation]/[PushUpThresholds.hipSevereDeviation].
  final double hipDeviation;

  /// Smoothed, baseline-corrected head-line deviation — compare against
  /// [PushUpThresholds.headDeviation].
  final double headDeviation;

  /// Smoothed, baseline-corrected knee-line deviation — compare against
  /// [PushUpThresholds.kneeAlignmentDeviation].
  final double kneeDeviation;

  /// Whether the hip/head/knee baselines have finished calibrating yet
  /// (see [PushUpThresholds.calibrationFrames]). Deviation values are
  /// relative to raw zero, not yet the user's own baseline, while `false`.
  final bool calibrated;
}

/// Rep-cycle phase tracked internally by [PushUpFormDetector], exposed on
/// [PushUpFeedback.phase] for host apps that want it (e.g. a progress
/// ring).
enum PushUpPhase {
  /// No person in frame / not enough landmarks.
  idle,

  /// At the top, elbow near-straight.
  ready,

  /// Elbow angle decreasing.
  descending,

  /// At or past target depth, direction settled or about to reverse.
  bottom,

  /// Elbow angle increasing back toward the top.
  ascending,
}
