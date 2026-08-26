import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'input_image_converter.dart';

/// Explicit mapping from [DeviceOrientation] to the "rotate clockwise to
/// reach portraitUp" degrees ML Kit expects — matches Google's own
/// camera+ML Kit sample. Written as a switch (not `.index * 90`) so it
/// stays correct even if the enum's declaration order ever changes.
int deviceOrientationToDegrees(DeviceOrientation orientation) {
  switch (orientation) {
    case DeviceOrientation.portraitUp:
      return 0;
    case DeviceOrientation.landscapeLeft:
      return 90;
    case DeviceOrientation.portraitDown:
      return 180;
    case DeviceOrientation.landscapeRight:
      return 270;
  }
}

/// Everything [PoseOverlayPainter] needs to map landmark coordinates onto
/// the canvas for a single detected frame.
class PoseFrame {
  const PoseFrame({
    required this.poses,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });

  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
}

/// Owns the [CameraController] + [PoseDetector] lifecycle: starts the
/// camera image stream, converts frames, runs pose detection, and emits
/// results as a [Stream<PoseFrame>].
///
/// One [PoseDetector] instance for the controller's lifetime, running in
/// [PoseDetectionMode.stream] for temporal smoothing across frames. A
/// drop-frame guard ensures only one inference is ever in flight.
class PoseStreamController {
  PoseStreamController({
    InputImageConverter? converter,
    PoseDetectionModel detectionModel = PoseDetectionModel.accurate,
  })  : _converter = converter ?? const InputImageConverter(),
        _poseDetector = PoseDetector(
          options: PoseDetectorOptions(
            mode: PoseDetectionMode.stream,
            model: detectionModel,
          ),
        );

  final InputImageConverter _converter;
  final PoseDetector _poseDetector;

  final StreamController<PoseFrame> _frameController =
      StreamController<PoseFrame>.broadcast();

  CameraController? _cameraController;
  CameraDescription? _cameraDescription;
  List<CameraDescription> _availableCameras = const [];
  bool _isDetecting = false;
  bool _disposed = false;

  /// Emits a [PoseFrame] every time a camera frame finishes running
  /// through the detector.
  Stream<PoseFrame> get poseStream => _frameController.stream;

  /// The live [CameraController], for feeding [CameraPreview].
  CameraController? get cameraController => _cameraController;

  CameraLensDirection? get currentLensDirection =>
      _cameraDescription?.lensDirection;

  /// Picks the matching [CameraDescription] for [lensDirection] and starts
  /// the [CameraController] with the platform-correct [ImageFormatGroup]
  /// (NV21 on Android, BGRA8888 on iOS).
  Future<void> initialize({
    required CameraLensDirection lensDirection,
    required ResolutionPreset resolutionPreset,
  }) async {
    _availableCameras =
        _availableCameras.isEmpty ? await availableCameras() : _availableCameras;

    final description = _availableCameras.firstWhere(
      (camera) => camera.lensDirection == lensDirection,
      orElse: () => _availableCameras.first,
    );
    _cameraDescription = description;

    final controller = CameraController(
      description,
      resolutionPreset,
      enableAudio: false,
      imageFormatGroup: defaultTargetImageFormatGroup(),
    );

    _cameraController = controller;
    await controller.initialize();
    if (_disposed) return;

    await controller.startImageStream(_onCameraImage);
  }

  void _onCameraImage(CameraImage image) {
    if (_isDetecting || _disposed) return;
    final description = _cameraDescription;
    if (description == null) return;

    _isDetecting = true;
    _processImage(image, description).whenComplete(() {
      _isDetecting = false;
    });
  }

  Future<void> _processImage(
    CameraImage image,
    CameraDescription description,
  ) async {
    try {
      final controller = _cameraController;
      if (controller == null) return;

      final inputImage = _converter.convert(
        image: image,
        cameraDescription: description,
        deviceOrientationDegrees:
            deviceOrientationToDegrees(controller.value.deviceOrientation),
      );
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (_disposed) return;

      _frameController.add(
        PoseFrame(
          poses: poses,
          imageSize: inputImage.metadata!.size,
          rotation: inputImage.metadata!.rotation,
          lensDirection: description.lensDirection,
        ),
      );
    } catch (_) {
      // Drop malformed/unsupported frames rather than crashing the stream.
    }
  }

  /// Stops the current stream, disposes the old controller, and
  /// reinitializes with the opposite lens direction.
  Future<void> switchCamera({required ResolutionPreset resolutionPreset}) async {
    final current = currentLensDirection ?? CameraLensDirection.back;
    final next = current == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    await _stopCamera();
    await initialize(lensDirection: next, resolutionPreset: resolutionPreset);
  }

  Future<void> _stopCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  /// Stops the image stream, disposes the [CameraController], and closes
  /// the [PoseDetector], in that order.
  Future<void> dispose() async {
    _disposed = true;
    await _stopCamera();
    await _poseDetector.close();
    await _frameController.close();
  }
}

/// NV21 on Android, BGRA8888 on iOS — the formats ML Kit's pose detector
/// expects on each platform.
ImageFormatGroup defaultTargetImageFormatGroup() {
  return defaultTargetPlatform == TargetPlatform.android
      ? ImageFormatGroup.nv21
      : ImageFormatGroup.bgra8888;
}
