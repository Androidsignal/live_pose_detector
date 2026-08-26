import 'package:flutter/material.dart';

import '../pushup/pushup_form_detector.dart'; // doc-referenced below
import '../pushup/pushup_types.dart';
import 'camera_pose_view.dart'; // doc-referenced below

/// Turnkey UI for [PushUpFeedback]: a rep-count chip plus a color-coded
/// message banner (green for correct posture/movement, your warning color
/// for anything that needs correcting, neutral while waiting) — the
/// message and color cross-fade smoothly frame to frame instead of
/// snapping, since [PushUpFormDetector] already debounces which state
/// reaches you.
///
/// Drop straight into a `Stack` over [CameraPoseView]:
///
/// ```dart
/// Stack(
///   children: [
///     CameraPoseView(onPosesDetected: (poses) {
///       feedbackNotifier.value = detector.evaluate(poses);
///     }),
///     Align(
///       alignment: Alignment.bottomCenter,
///       child: ValueListenableBuilder<PushUpFeedback?>(
///         valueListenable: feedbackNotifier,
///         builder: (context, feedback, _) =>
///             PushUpFeedbackBanner(feedback: feedback),
///       ),
///     ),
///   ],
/// )
/// ```
///
/// Renders nothing (not even reserved space) until the first [feedback]
/// arrives, so it doesn't flash empty chrome before detection starts.
class PushUpFeedbackBanner extends StatelessWidget {
  const PushUpFeedbackBanner({
    super.key,
    required this.feedback,
    this.successColor = const Color(0xFF2E7D32),
    this.warningColor = const Color(0xFFE65100),
    this.neutralColor = const Color(0xFF455A64),
    this.textColor = Colors.white,
    this.showRepCount = true,
    this.animationDuration = const Duration(milliseconds: 250),
    this.margin = const EdgeInsets.all(16),
  });

  /// Latest detector output. `null` renders nothing — pass this straight
  /// through from a `ValueListenableBuilder`/`StreamBuilder` without
  /// special-casing the "not started yet" frame yourself.
  final PushUpFeedback? feedback;

  /// Background color while [PushUpFeedback.color] is
  /// [PushUpFeedbackColor.success].
  final Color successColor;

  /// Background color while [PushUpFeedback.color] is
  /// [PushUpFeedbackColor.warning].
  final Color warningColor;

  /// Background color while [PushUpFeedback.color] is
  /// [PushUpFeedbackColor.neutral].
  final Color neutralColor;

  /// Text/icon color, constant across all three states — pick one that
  /// reads on all of [successColor]/[warningColor]/[neutralColor].
  final Color textColor;

  /// Whether to show the "Reps: N" chip above the message.
  final bool showRepCount;

  /// How long the background-color ease and message cross-fade take.
  final Duration animationDuration;

  /// Outer spacing — matches typical `Positioned`/`SafeArea` placement
  /// without the caller needing to add their own `Padding`.
  final EdgeInsetsGeometry margin;

  Color _colorFor(PushUpFeedbackColor color) {
    switch (color) {
      case PushUpFeedbackColor.success:
        return successColor;
      case PushUpFeedbackColor.warning:
        return warningColor;
      case PushUpFeedbackColor.neutral:
        return neutralColor;
    }
  }

  IconData _iconFor(PushUpFeedbackColor color) {
    switch (color) {
      case PushUpFeedbackColor.success:
        return Icons.check_circle;
      case PushUpFeedbackColor.warning:
        return Icons.warning_amber_rounded;
      case PushUpFeedbackColor.neutral:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = this.feedback;
    if (feedback == null) return const SizedBox.shrink();

    return Padding(
      padding: margin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showRepCount) ...[
            _RepChip(count: feedback.repCount, textColor: textColor),
            const SizedBox(height: 8),
          ],
          AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _colorFor(feedback.color),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_iconFor(feedback.color), color: textColor),
                const SizedBox(width: 8),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: animationDuration,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: Text(
                      feedback.message,
                      key: ValueKey(feedback.state),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepChip extends StatelessWidget {
  const _RepChip({required this.count, required this.textColor});

  final int count;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Reps: $count',
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
