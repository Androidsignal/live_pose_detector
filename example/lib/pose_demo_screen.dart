import 'package:flutter/material.dart';
import 'package:live_pose_detector/live_pose_detector.dart';

/// Full-screen pose view — CameraPoseView owns permission, camera, and
/// skeleton rendering. Extra here: a back button and a push-up form banner
/// (green for correct posture/movement, warning color for anything that
/// needs correcting, neutral while waiting) driven entirely by
/// [PushUpFormDetector] off `onPosesDetected`.
class PoseDemoScreen extends StatefulWidget {
  const PoseDemoScreen({super.key, required this.initialLensDirection});

  final CameraLensDirection initialLensDirection;

  @override
  State<PoseDemoScreen> createState() => _PoseDemoScreenState();
}

class _PoseDemoScreenState extends State<PoseDemoScreen> {
  final PushUpFormDetector _detector = PushUpFormDetector();

  // ValueNotifier, not setState — this fires on every detected frame, and
  // setState here would rebuild the whole Stack (camera preview included)
  // per frame. See CameraPoseView's own _frameNotifier for the same fix.
  final ValueNotifier<PushUpFeedback?> _feedback = ValueNotifier(null);

  void _onPosesDetected(List<Pose> poses) {
    _feedback.value = _detector.evaluate(poses);
  }

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          CameraPoseView(
            initialLensDirection: widget.initialLensDirection,
            onPosesDetected: _onPosesDetected,
          ),
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<PushUpFeedback?>(
                valueListenable: _feedback,
                builder: (context, feedback, _) => PushUpFeedbackBanner(feedback: feedback),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
