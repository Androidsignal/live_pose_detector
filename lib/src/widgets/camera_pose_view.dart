import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/pose_overlay_config.dart';
import '../detection/camera_permission_denied_exception.dart';
import '../detection/pose_stream_controller.dart';
import '../painting/pose_overlay_painter.dart';

/// Handle for advanced use: render your own switch button (instead of the
/// built-in FAB) and drive the camera directly.
///
/// Obtain one by passing a [GlobalKey<CameraPoseViewState>] as the `key` of
/// a [CameraPoseView] and calling `key.currentState?.switchCamera()`.
abstract class CameraPoseViewController {
  Future<void> switchCamera();
}

/// Turnkey pose-tracking view: live camera feed with a skeleton (dots +
/// connecting lines) tracking the person in frame, updated every frame,
/// front/back camera switchable. On the front camera, preview and
/// skeleton are mirrored together (one `Transform` around both) for a
/// natural selfie view.
///
/// Drop this into a screen once camera permission is granted — camera
/// capture, ML Kit wiring, and skeleton rendering are all owned internally.
class CameraPoseView extends StatefulWidget {
  const CameraPoseView({
    super.key,
    this.initialLensDirection = CameraLensDirection.back,
    this.config = const PoseOverlayConfig(),
    this.onPosesDetected,
    this.onError,
  });

  /// Camera to start on. Defaults to the back camera.
  final CameraLensDirection initialLensDirection;

  /// Dot/line appearance, confidence threshold, skeleton topology, and
  /// camera resolution — see [PoseOverlayConfig].
  final PoseOverlayConfig config;

  /// Optional passthrough for host app logic (rep counting, angle
  /// calculations, gesture triggers) — called with every detected frame's
  /// poses, off the same landmark stream the painter uses. No extra
  /// detection work is run for this callback.
  final ValueChanged<List<Pose>>? onPosesDetected;

  /// Called when camera or detector initialization fails (e.g. permission
  /// denied, camera in use elsewhere). If unset, the widget shows a
  /// built-in error view with a Retry button instead.
  final ValueChanged<Object>? onError;

  @override
  State<CameraPoseView> createState() => CameraPoseViewState();
}

class CameraPoseViewState extends State<CameraPoseView>
    with WidgetsBindingObserver
    implements CameraPoseViewController {
  late PoseStreamController _controller;

  /// Latest detected frame, pushed straight to the [CustomPaint] via
  /// [ValueListenableBuilder] — bypasses [setState] so only the skeleton
  /// repaints each frame instead of the whole preview tree (camera preview,
  /// FittedBox, Stack). That per-frame full-tree rebuild was the source of
  /// visible drawing lag.
  final ValueNotifier<PoseFrame?> _frameNotifier = ValueNotifier(null);
  bool _isReady = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = PoseStreamController(detectionModel: widget.config.detectionModel);
    _start(widget.initialLensDirection);
  }

  Future<void> _start(CameraLensDirection lensDirection) async {
    setState(() => _error = null);
    try {
      if (widget.config.requestCameraPermission) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          throw CameraPermissionDeniedException(status);
        }
      }
      await _controller.initialize(
        lensDirection: lensDirection,
        resolutionPreset: widget.config.resolutionPreset,
      );
      _controller.poseStream.listen(_onFrame);
      if (mounted) setState(() => _isReady = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      widget.onError?.call(error);
    }
  }

  /// Retries initialization after a failure (e.g. after the user grants
  /// camera permission and comes back).
  Future<void> retry() => _start(_lastLensDirection ?? widget.initialLensDirection);

  void _onFrame(PoseFrame frame) {
    if (!mounted) return;
    _frameNotifier.value = frame;
    final callback = widget.onPosesDetected;
    if (callback != null) callback(frame.poses);
  }

  @override
  Future<void> switchCamera() async {
    setState(() {
      _isReady = false;
      _error = null;
    });
    try {
      await _controller.switchCamera(
        resolutionPreset: widget.config.resolutionPreset,
      );
      _controller.poseStream.listen(_onFrame);
      if (mounted) setState(() => _isReady = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      widget.onError?.call(error);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Camera released on background — reinitialized on resume, avoids
      // "camera already in use" errors.
      final lensDirection =
          _controller.currentLensDirection ?? widget.initialLensDirection;
      _controller.dispose();
      _controller = PoseStreamController(detectionModel: widget.config.detectionModel);
      _lastLensDirection = lensDirection;
    } else if (state == AppLifecycleState.resumed) {
      _start(_lastLensDirection ?? widget.initialLensDirection);
    }
  }

  CameraLensDirection? _lastLensDirection;

  String _describeError(Object error) {
    if (error is CameraPermissionDeniedException) {
      return error.status.isPermanentlyDenied
          ? 'Camera permission permanently denied.\nOpen Settings to grant it, then retry.'
          : 'Camera permission is required to detect pose.';
    }
    if (error is CameraException) {
      switch (error.code) {
        case 'CameraAccessDenied':
        case 'CameraAccessDeniedWithoutPrompt':
        case 'CameraAccessRestricted':
          return 'Camera permission is required to detect pose.\nGrant it in system settings and retry.';
        default:
          return 'Camera error: ${error.description ?? error.code}';
      }
    }
    return 'Could not start the camera.\n$error';
  }

  bool _needsAppSettings(Object error) =>
      error is CameraPermissionDeniedException && error.status.isPermanentlyDenied;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _frameNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null && widget.onError == null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, color: Colors.white54, size: 48),
                const SizedBox(height: 12),
                Text(
                  _describeError(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_needsAppSettings(error)) ...[
                      const OutlinedButton(
                        onPressed: openAppSettings,
                        child: Text('Open Settings'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton(onPressed: retry, child: const Text('Retry')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cameraController = _controller.cameraController;
    if (!_isReady ||
        cameraController == null ||
        !cameraController.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // CameraPreview never mirrors the front camera on its own (checked:
        // no flip anywhere in the plugin) — so preview and skeleton are
        // flipped together, here, as one unit. Mirroring only the overlay
        // (or only the preview) would desync them.
        Widget previewAndOverlay = Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cameraController.value.previewSize?.height ??
                    size.width,
                height: cameraController.value.previewSize?.width ??
                    size.height,
                child: CameraPreview(cameraController),
              ),
            ),
            RepaintBoundary(
              child: ValueListenableBuilder<PoseFrame?>(
                valueListenable: _frameNotifier,
                builder: (context, frame, _) {
                  return CustomPaint(
                    size: size,
                    painter: PoseOverlayPainter(frame: frame, config: widget.config),
                  );
                },
              ),
            ),
          ],
        );

        if (_controller.currentLensDirection == CameraLensDirection.front) {
          previewAndOverlay = Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: previewAndOverlay,
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            previewAndOverlay,
            if (widget.config.showCameraSwitchButton)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: switchCamera,
                  child: const Icon(Icons.cameraswitch),
                ),
              ),
          ],
        );
      },
    );
  }
}
