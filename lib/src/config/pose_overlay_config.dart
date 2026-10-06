import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_connections.dart';

/// Where [CameraPoseView] places its built-in camera switch button.
enum CameraSwitchButtonPosition { topLeft, topRight, bottomLeft, bottomRight }

/// Single configuration object for [CameraPoseView] — dot/line appearance,
/// confidence gating, skeleton topology and camera capture quality.
///
/// Mirrors `face_overlay_kit`'s config pattern: one object, fully
/// overridable, sane defaults.
@immutable
class PoseOverlayConfig {
  const PoseOverlayConfig({
    this.dotColor = Colors.greenAccent,
    this.lineColor = Colors.yellowAccent,
    this.dotRadius = 5,
    this.lineWidth = 3,
    this.confidenceThreshold = 0.5,
    this.connections = kPoseConnections,
    this.resolutionPreset = ResolutionPreset.medium,
    this.showCameraSwitchButton = true,
    this.cameraSwitchButtonPosition = CameraSwitchButtonPosition.bottomRight,
    this.detectionModel = PoseDetectionModel.accurate,
    this.haloColor = Colors.black45,
    this.requestCameraPermission = true,
    this.showFaceLandmarks = true,
    this.showFingerLandmarks = true,
    this.showLegLandmarks = true,
    this.showArmLandmarks = true,
    this.showTorsoLandmarks = true,
    this.hiddenLandmarks = const {},
  });

  /// Color of the landmark dots.
  final Color dotColor;

  /// Color of the connecting skeleton lines.
  final Color lineColor;

  /// Radius (in logical pixels) of each landmark dot.
  final double dotRadius;

  /// Stroke width (in logical pixels) of each skeleton line.
  final double lineWidth;

  /// Landmarks with `likelihood` below this value are neither drawn nor
  /// used to draw a connecting line. Range 0.0–1.0, default 0.5.
  final double confidenceThreshold;

  /// Landmark pairs that get a connecting line drawn between them.
  /// Defaults to [kPoseConnections]; pass a custom list (e.g. drop face
  /// points, add a custom subset) without touching package internals.
  final List<List<PoseLandmarkType>> connections;

  /// Camera capture quality. Balances landmark accuracy vs on-device
  /// inference speed — default [ResolutionPreset.medium].
  final ResolutionPreset resolutionPreset;

  /// Whether [CameraPoseView] renders its own built-in front/back camera
  /// switch FAB. Set false to render your own control and call
  /// `CameraPoseViewController.switchCamera()` directly.
  final bool showCameraSwitchButton;

  /// Corner of the preview where the built-in camera switch button sits.
  /// Default [CameraSwitchButtonPosition.bottomRight]. Ignored when
  /// [showCameraSwitchButton] is false.
  final CameraSwitchButtonPosition cameraSwitchButtonPosition;

  /// ML Kit model quality. [PoseDetectionModel.accurate] gives more precise
  /// landmarks at higher inference cost; [PoseDetectionModel.base] trades
  /// precision for speed. Default is [PoseDetectionModel.accurate].
  final PoseDetectionModel detectionModel;

  /// Semi-transparent halo drawn under dots and lines so the skeleton
  /// stays legible over both light and dark backgrounds. Set to
  /// `Colors.transparent` to disable.
  final Color haloColor;

  /// If true (default), [CameraPoseView] requests camera permission itself
  /// before starting the camera — no separate permission step needed in
  /// your app. Set false if your app already handles permission and wants
  /// to skip the extra request.
  final bool requestCameraPermission;

  /// Whether face points ([kFaceLandmarks]) and their lines are drawn.
  final bool showFaceLandmarks;

  /// Whether finger points ([kFingerLandmarks]) and their lines are drawn.
  final bool showFingerLandmarks;

  /// Whether leg points from the knee down ([kLegLandmarks]) and their
  /// lines are drawn.
  final bool showLegLandmarks;

  /// Whether arm points ([kArmLandmarks] — elbows, wrists) and their lines
  /// are drawn.
  final bool showArmLandmarks;

  /// Whether torso points ([kTorsoLandmarks] — hips) and their lines are
  /// drawn.
  final bool showTorsoLandmarks;

  /// Any individual points to hide on top of the `show*Landmarks` group
  /// toggles, e.g. `{PoseLandmarkType.leftHip}`.
  final Set<PoseLandmarkType> hiddenLandmarks;

  /// Whether [type] should be drawn, given the `show*Landmarks` toggles.
  /// A line is only drawn when both of its ends are visible.
  bool isLandmarkVisible(PoseLandmarkType type) {
    if (!showFaceLandmarks && kFaceLandmarks.contains(type)) return false;
    if (!showFingerLandmarks && kFingerLandmarks.contains(type)) return false;
    if (!showLegLandmarks && kLegLandmarks.contains(type)) return false;
    if (!showArmLandmarks && kArmLandmarks.contains(type)) return false;
    if (!showTorsoLandmarks && kTorsoLandmarks.contains(type)) return false;
    if (hiddenLandmarks.contains(type)) return false;
    return true;
  }

  PoseOverlayConfig copyWith({
    Color? dotColor,
    Color? lineColor,
    double? dotRadius,
    double? lineWidth,
    double? confidenceThreshold,
    List<List<PoseLandmarkType>>? connections,
    ResolutionPreset? resolutionPreset,
    bool? showCameraSwitchButton,
    CameraSwitchButtonPosition? cameraSwitchButtonPosition,
    PoseDetectionModel? detectionModel,
    Color? haloColor,
    bool? requestCameraPermission,
    bool? showFaceLandmarks,
    bool? showFingerLandmarks,
    bool? showLegLandmarks,
    bool? showArmLandmarks,
    bool? showTorsoLandmarks,
    Set<PoseLandmarkType>? hiddenLandmarks,
  }) {
    return PoseOverlayConfig(
      dotColor: dotColor ?? this.dotColor,
      lineColor: lineColor ?? this.lineColor,
      dotRadius: dotRadius ?? this.dotRadius,
      lineWidth: lineWidth ?? this.lineWidth,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      connections: connections ?? this.connections,
      resolutionPreset: resolutionPreset ?? this.resolutionPreset,
      showCameraSwitchButton:
          showCameraSwitchButton ?? this.showCameraSwitchButton,
      cameraSwitchButtonPosition:
          cameraSwitchButtonPosition ?? this.cameraSwitchButtonPosition,
      detectionModel: detectionModel ?? this.detectionModel,
      haloColor: haloColor ?? this.haloColor,
      requestCameraPermission:
          requestCameraPermission ?? this.requestCameraPermission,
      showFaceLandmarks: showFaceLandmarks ?? this.showFaceLandmarks,
      showFingerLandmarks: showFingerLandmarks ?? this.showFingerLandmarks,
      showLegLandmarks: showLegLandmarks ?? this.showLegLandmarks,
      showArmLandmarks: showArmLandmarks ?? this.showArmLandmarks,
      showTorsoLandmarks: showTorsoLandmarks ?? this.showTorsoLandmarks,
      hiddenLandmarks: hiddenLandmarks ?? this.hiddenLandmarks,
    );
  }
}
