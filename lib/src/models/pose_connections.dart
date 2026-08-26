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
