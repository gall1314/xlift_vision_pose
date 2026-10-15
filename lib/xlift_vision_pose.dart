import 'dart:convert';

import 'package:flutter/services.dart';

class XliftVisionPose {
  static const MethodChannel _channel = MethodChannel('xlift_vision_pose');

  /// True on iOS 17+ where VNDetectHumanBodyPose3DRequest exists.
  static Future<bool> isAvailable() async {
    try {
      return (await _channel.invokeMethod<bool>('isAvailable')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Runs Apple Vision 3D body pose over [videoPath], sampled at [fps].
  ///
  /// Returns:
  /// {
  ///   sourceFps, sampledFps,
  ///   frames: [ { t, confidence?, bodyHeight?,
  ///               joints?: { root: {x,y,z,px,py}, leftKnee: {...}, ... } } ]
  /// }
  /// x/y/z are meters in Vision's model space (y up). px/py are normalized
  /// image coordinates with a top-left origin, for drawing overlays.
  static Future<Map<String, dynamic>> analyzeVideo(String videoPath,
      {double fps = 12}) async {
    final raw = await _channel.invokeMethod<String>(
      'analyzeVideo',
      {'path': videoPath, 'fps': fps},
    );
    return jsonDecode(raw ?? '{}') as Map<String, dynamic>;
  }
}
