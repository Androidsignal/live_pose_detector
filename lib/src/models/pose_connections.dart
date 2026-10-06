import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Default skeleton topology: pairs of landmarks that get a line drawn
/// between them when both ends pass the confidence threshold.
///
/// Reuses ML Kit's own [PoseLandmarkType] enum directly — no custom pose
/// model layer, no duplicate mapping code.
const List<List<PoseLandmarkType>> kPoseConnections = [
  // Face
  [PoseLandmarkType.leftEar, PoseLandmarkType.leftEye],
  [PoseLandmarkType.leftEye, PoseLandmarkType.nose],
  [PoseLandmarkType.nose, PoseLandmarkType.rightEye],
  [PoseLandmarkType.rightEye, PoseLandmarkType.rightEar],

  // Shoulders
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],

  // Left arm + hand (fan out from wrist, matches MediaPipe's pose topology)
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
  [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
  [PoseLandmarkType.leftWrist, PoseLandmarkType.leftThumb],
  [PoseLandmarkType.leftWrist, PoseLandmarkType.leftIndex],
  [PoseLandmarkType.leftWrist, PoseLandmarkType.leftPinky],

  // Right arm + hand
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
  [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
  [PoseLandmarkType.rightWrist, PoseLandmarkType.rightThumb],
  [PoseLandmarkType.rightWrist, PoseLandmarkType.rightIndex],
  [PoseLandmarkType.rightWrist, PoseLandmarkType.rightPinky],

  // Torso sides
  [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
  [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],

  // Hips
  [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],

  // Left leg + foot (ankle-heel-footIndex triangle, not a dead-end point)
  [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
  [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
  [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
  [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
  [PoseLandmarkType.leftFootIndex, PoseLandmarkType.leftAnkle],

  // Right leg + foot
  [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
  [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
  [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
  [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
  [PoseLandmarkType.rightFootIndex, PoseLandmarkType.rightAnkle],
];

/// Face landmarks — hidden when [PoseOverlayConfig.showFaceLandmarks] is
/// false.
const Set<PoseLandmarkType> kFaceLandmarks = {
  PoseLandmarkType.nose,
  PoseLandmarkType.leftEyeInner,
  PoseLandmarkType.leftEye,
  PoseLandmarkType.leftEyeOuter,
  PoseLandmarkType.rightEyeInner,
  PoseLandmarkType.rightEye,
  PoseLandmarkType.rightEyeOuter,
  PoseLandmarkType.leftEar,
  PoseLandmarkType.rightEar,
  PoseLandmarkType.leftMouth,
  PoseLandmarkType.rightMouth,
};

/// Arm landmarks (elbows, wrists) — hidden when
/// [PoseOverlayConfig.showArmLandmarks] is false. Shoulders stay visible.
const Set<PoseLandmarkType> kArmLandmarks = {
  PoseLandmarkType.leftElbow,
  PoseLandmarkType.leftWrist,
  PoseLandmarkType.rightElbow,
  PoseLandmarkType.rightWrist,
};

/// Torso landmarks (hips) — hidden when
/// [PoseOverlayConfig.showTorsoLandmarks] is false, which removes the
/// shoulder-to-hip and hip-to-hip lines. Shoulders stay visible.
const Set<PoseLandmarkType> kTorsoLandmarks = {
  PoseLandmarkType.leftHip,
  PoseLandmarkType.rightHip,
};

/// Finger landmarks (thumb, index, pinky) — hidden when
/// [PoseOverlayConfig.showFingerLandmarks] is false. Wrists stay visible.
const Set<PoseLandmarkType> kFingerLandmarks = {
  PoseLandmarkType.leftThumb,
  PoseLandmarkType.leftIndex,
  PoseLandmarkType.leftPinky,
  PoseLandmarkType.rightThumb,
  PoseLandmarkType.rightIndex,
  PoseLandmarkType.rightPinky,
};

/// Leg landmarks from the knee down — hidden when
/// [PoseOverlayConfig.showLegLandmarks] is false. Hips stay visible.
const Set<PoseLandmarkType> kLegLandmarks = {
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.leftAnkle,
  PoseLandmarkType.leftHeel,
  PoseLandmarkType.leftFootIndex,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.rightAnkle,
  PoseLandmarkType.rightHeel,
  PoseLandmarkType.rightFootIndex,
};
