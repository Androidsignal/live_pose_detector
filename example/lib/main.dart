import 'package:flutter/material.dart';

import 'start_screen.dart';

void main() => runApp(const PoseDetectorExampleApp());

class PoseDetectorExampleApp extends StatelessWidget {
  const PoseDetectorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Pose Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.greenAccent,
        brightness: Brightness.dark,
      ),
      home: const StartScreen(),
    );
  }
}
