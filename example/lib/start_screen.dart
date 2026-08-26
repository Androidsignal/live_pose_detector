import 'package:flutter/material.dart';
import 'package:live_pose_detector/live_pose_detector.dart';

import 'pose_demo_screen.dart';

/// Landing screen: pick a starting camera, tap Start. Camera permission is
/// handled by [CameraPoseView] itself — nothing to wire up here.
class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  CameraLensDirection _lensDirection = CameraLensDirection.back;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.accessibility_new, size: 96, color: Colors.greenAccent),
              const SizedBox(height: 16),
              const Text('Live Pose Detector', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              SegmentedButton<CameraLensDirection>(
                segments: const [
                  ButtonSegment(value: CameraLensDirection.back, label: Text('Back camera')),
                  ButtonSegment(value: CameraLensDirection.front, label: Text('Front camera')),
                ],
                selected: {_lensDirection},
                onSelectionChanged: (selection) => setState(() => _lensDirection = selection.first),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PoseDemoScreen(initialLensDirection: _lensDirection),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
