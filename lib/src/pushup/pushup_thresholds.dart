import 'package:flutter/foundation.dart';

/// Tunable thresholds for [PushUpFormDetector]. All angle/deviation
/// defaults are approximate, biomechanics-derived starting points, loosened
/// from their theoretical ideal to tolerate real single-camera 2D
/// perspective noise (a straight body line measured off-axis, or at the
/// bottom of a rep where the torso tilts relative to the camera, reads as
/// slightly "off" even with perfect form) — [PushUpFormDetector] also
/// auto-calibrates against the user's own starting pose (see
/// [calibrationFrames]) rather than relying on these being exactly right
/// out of the box. Every value is still overridable; see
/// [PushUpFeedback.debug] for the raw numbers to tune against your own
/// camera setup.
@immutable
class PushUpThresholds {
  const PushUpThresholds({
    this.topElbowAngle = 155,
    this.bottomElbowAngle = 100,
    this.tooLowElbowAngle = 55,
    this.hipMildDeviation = 0.07,
    this.hipSevereDeviation = 0.16,
    this.headDeviation = 0.14,
    this.kneeAlignmentDeviation = 0.10,
    this.elbowAbductionMin = 15,
    this.elbowAbductionMax = 60,
    this.fastMovementDegreesPerSecond = 250,
    this.stagnantHold = const Duration(seconds: 3),
    this.poseLostGrace = const Duration(milliseconds: 500),
    this.minWarningPersistence = const Duration(milliseconds: 200),
    this.calibrationFrames = 5,
    this.calibrationMaxSpread = 0.08,
    this.calibrationMaxSpreadDegrees = 15,
    this.maxBodyRotationDegrees = 45,
    this.minLandmarkConfidence = 0.5,
    this.depthToleranceExpansion = 0.6,
    this.invertBodyLineSign = false,
  });

  /// Elbow angle (shoulder-elbow-wrist, degrees) at/above which the arms
  /// count as the "top" of the rep.
  final double topElbowAngle;

  /// Elbow angle at/below which the rep has entered the target bottom
  /// depth zone.
  final double bottomElbowAngle;

  /// Elbow angle below which the descent has gone past a safe/target
  /// depth ("Going Too Low").
  final double tooLowElbowAngle;

  /// Normalized (torso-length-scaled) hip deviation *from the user's own
  /// calibrated baseline* within which the back counts as straight.
  final double hipMildDeviation;

  /// Beyond this normalized hip deviation, the issue is reported as
  /// "Body Too High"/"Body Too Low" instead of the milder
  /// "Back Not Straight".
  final double hipSevereDeviation;

  /// Normalized head/neck deviation from baseline beyond which the neck is
  /// reported as "Head Too Low"/"Head Too High".
  final double headDeviation;

  /// Normalized knee deviation from baseline beyond which legs are
  /// reported as "Wrong Body Alignment".
  final double kneeAlignmentDeviation;

  /// Elbow-shoulder-hip abduction angle range (degrees) that counts as
  /// good elbow position. Below flags "Elbows Too Close", above flags
  /// "Elbows Too Wide".
  final double elbowAbductionMin;
  final double elbowAbductionMax;

  /// Elbow-angle rate of change (degrees/second) beyond which a
  /// descending/ascending rep is flagged as "Movement Too Fast".
  final double fastMovementDegreesPerSecond;

  /// How long the user can hold a correct top position before feedback
  /// switches from "Correct Form Maintained" to "No Movement Detected".
  final Duration stagnantHold;

  /// How long a dropped detection (person briefly out of frame / a
  /// landmark momentarily occluded) is tolerated before resetting to
  /// "Starting Position" — avoids flickering the feedback on a single
  /// missed frame.
  final Duration poseLostGrace;

  /// How long a posture issue (back/head/elbow/knee line checks) must
  /// keep being the top-priority issue before it's actually shown —
  /// absorbs single-frame landmark jitter (very common mid-rep, when the
  /// body is moving fastest and landmarks are noisiest) so a correct
  /// descent doesn't flash a warning. Depth/tempo/rep-summary feedback
  /// (too fast, not low enough, etc.) is event-like and always shown
  /// immediately — only the four line/angle posture checks debounce.
  final Duration minWarningPersistence;

  /// Number of frames, collected as soon as a person is detected,
  /// averaged to establish each user's own neutral hip/head/knee
  /// baseline — cancels out camera-angle bias and body-shape differences
  /// instead of assuming a universal "straight" reading of 0. Assumes the
  /// user starts each set in a genuinely correct position; recalibrates
  /// on [PushUpFormDetector.reset].
  final int calibrationFrames;

  /// Max spread (highest − lowest) allowed among the in-progress
  /// calibration samples. A new sample that would push the window past
  /// this restarts the streak instead of getting averaged in — see
  /// `_DeviationTracker.maybeCalibrate`.
  final double calibrationMaxSpread;

  /// Same idea as [calibrationMaxSpread], but for the shoulder→ankle body
  /// angle (degrees) used to detect "no longer in a push-up stance" — see
  /// [maxBodyRotationDegrees].
  final double calibrationMaxSpreadDegrees;

  /// How far (degrees) the shoulder→ankle line can rotate from its
  /// calibrated push-up orientation before rep logic stops entirely and
  /// feedback drops to "Get into the push-up position." Elbow angle alone
  /// can't tell a prone push-up from someone standing and bending their
  /// arm — both bend the elbow through the same range — but the overall
  /// body line barely moves through a real rep and rotates sharply the
  /// moment someone stands up.
  final double maxBodyRotationDegrees;

  /// Minimum average landmark likelihood (0–1) for a side (left/right) to
  /// be used at all. Below this, the frame is treated the same as no
  /// person detected rather than judged on unreliable landmarks.
  final double minLandmarkConfidence;

  /// How much extra hip/head/knee deviation tolerance to allow at full
  /// rep depth, as a fraction added on top of the base tolerance (0.6 =
  /// 60% looser at the bottom, scaling linearly from 0% at the top). A
  /// single side-on 2D camera reads more deviation than actually exists
  /// as the torso foreshortens with a bent elbow — this compensates so a
  /// correct rep doesn't read as worse form simply for being deeper.
  final double depthToleranceExpansion;

  /// Flip if the hip/head/knee deviation checks report the opposite of
  /// what's physically happening for your camera setup — the sign of a
  /// perpendicular-line deviation is orientation-dependent (see
  /// `signedLineDeviation`) and calibration cancels a *constant* offset,
  /// not a flipped sign.
  final bool invertBodyLineSign;
}
