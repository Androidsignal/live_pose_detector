/// Real-time human pose detection with skeleton overlay for Flutter.
///
/// Drop [CameraPoseView] into a screen to get a live camera feed with an
/// ML Kit pose skeleton drawn over it — camera capture, detection, and
/// rendering are all owned by this package.
library live_pose_detector;

export 'package:camera/camera.dart' show CameraLensDirection, ResolutionPreset;
export 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    show Pose, PoseLandmark, PoseLandmarkType, PoseDetectionModel;

export 'src/config/pose_overlay_config.dart';
export 'src/detection/camera_permission_denied_exception.dart';
export 'src/detection/pose_stream_controller.dart' show PoseFrame;
export 'src/models/pose_connections.dart';
export 'src/painting/pose_overlay_painter.dart';
export 'src/pushup/pushup_form_detector.dart';
export 'src/pushup/pushup_thresholds.dart';
export 'src/pushup/pushup_types.dart';
export 'src/utils/pose_math.dart';
export 'src/widgets/camera_pose_view.dart';
export 'src/widgets/pushup_feedback_banner.dart';
