import 'dart:math' as math;
import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Angle (in degrees, 0–180) at [center] formed by the two rays
/// `center → a` and `center → b`.
///
/// Common building block for logic hung off [CameraPoseView.onPosesDetected]
/// — e.g. an elbow/knee angle for rep counting, or a threshold check for a
/// gesture trigger — without every host app re-deriving the same trig.
double angleBetweenLandmarks(
  PoseLandmark a,
  PoseLandmark center,
  PoseLandmark b,
) {
  final v1 = Offset(a.x - center.x, a.y - center.y);
  final v2 = Offset(b.x - center.x, b.y - center.y);
  final magnitudes = v1.distance * v2.distance;
  if (magnitudes == 0) return 0;

  final dot = v1.dx * v2.dx + v1.dy * v2.dy;
  final radians = math.acos((dot / magnitudes).clamp(-1.0, 1.0));
  return radians * 180 / math.pi;
}

/// Signed perpendicular distance of [point] from the infinite line through
/// [lineStart] and [lineEnd], normalized by the line's length — a
/// dimensionless, scale-invariant measure of how far off a straight line
/// [point] sits.
///
/// [angleBetweenLandmarks] alone can't tell a body-line check (e.g. a
/// push-up's shoulder→hip→ankle plank line) which *side* a point has
/// drifted to — a vertex angle collapses symmetrically toward the same
/// magnitude whether the hip sags below the line or pikes above it. This
/// fills that gap: 0 means [point] sits exactly on the line, and the sign
/// flips depending on which side it's drifted to.
///
/// Which side is "positive" depends on image coordinate orientation
/// (camera facing, device rotation) — there's no universal answer without
/// a calibration frame, so callers calibrate the sign once for their setup
/// rather than assuming a fixed meaning.
double signedLineDeviation(Offset lineStart, Offset lineEnd, Offset point) {
  final lineVec = lineEnd - lineStart;
  final lineLengthSquared = lineVec.dx * lineVec.dx + lineVec.dy * lineVec.dy;
  if (lineLengthSquared == 0) return 0;

  final pointVec = point - lineStart;
  final cross = lineVec.dx * pointVec.dy - lineVec.dy * pointVec.dx;
  return cross / lineLengthSquared;
}

/// [signedLineDeviation] taken directly from landmarks, mirroring
/// [angleBetweenLandmarks]'s landmark-in-degrees-out convenience.
double signedLandmarkLineDeviation(
  PoseLandmark lineStart,
  PoseLandmark lineEnd,
  PoseLandmark point,
) {
  return signedLineDeviation(
    Offset(lineStart.x, lineStart.y),
    Offset(lineEnd.x, lineEnd.y),
    Offset(point.x, point.y),
  );
}
