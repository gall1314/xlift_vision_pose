import Flutter
import UIKit
import AVFoundation
import Vision
import simd

public class XliftVisionPosePlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "xlift_vision_pose",
                                       binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(XliftVisionPosePlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      if #available(iOS 17.0, *) { result(true) } else { result(false) }

    case "analyzeVideo":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "ARGS", message: "path required", details: nil))
        return
      }
      let targetFps = (args["fps"] as? Double) ?? 12.0
      guard #available(iOS 17.0, *) else {
        result(FlutterError(code: "UNAVAILABLE", message: "iOS 17+ required", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let json = try self.analyze(path: path, targetFps: targetFps)
          DispatchQueue.main.async { result(json) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "ANALYZE",
                                message: error.localizedDescription, details: nil))
          }
        }
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Core

  @available(iOS 17.0, *)
  private func analyze(path: String, targetFps: Double) throws -> String {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .video).first else {
      throw NSError(domain: "xlift", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "no video track"])
    }

    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    output.alwaysCopiesSampleData = false
    reader.add(output)

    let orientation = Self.orientation(for: track.preferredTransform)
    let nominal = Double(track.nominalFrameRate > 0 ? track.nominalFrameRate : 30)
    let stride = max(1, Int((nominal / targetFps).rounded()))

    let jointNames: [(String, VNHumanBodyPose3DObservation.JointName)] = [
      ("root", .root), ("spine", .spine), ("centerShoulder", .centerShoulder),
      ("centerHead", .centerHead), ("topHead", .topHead),
      ("leftShoulder", .leftShoulder), ("rightShoulder", .rightShoulder),
      ("leftElbow", .leftElbow), ("rightElbow", .rightElbow),
      ("leftWrist", .leftWrist), ("rightWrist", .rightWrist),
      ("leftHip", .leftHip), ("rightHip", .rightHip),
      ("leftKnee", .leftKnee), ("rightKnee", .rightKnee),
      ("leftAnkle", .leftAnkle), ("rightAnkle", .rightAnkle),
    ]

    var frames: [[String: Any]] = []
    var index = 0
    reader.startReading()

    while let sample = output.copyNextSampleBuffer() {
      defer { index += 1 }
      if index % stride != 0 { continue }
      guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }
      let t = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))

      let request = VNDetectHumanBodyPose3DRequest()
      let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                          orientation: orientation, options: [:])
      try? handler.perform([request])

      var frame: [String: Any] = ["t": t]
      if let obs = request.results?.first {
        var joints: [String: Any] = [:]
        for (key, name) in jointNames {
          guard let p = try? obs.recognizedPoint(name) else { continue }
          let pos = p.position.columns.3
          guard pos.x.isFinite, pos.y.isFinite, pos.z.isFinite else { continue }
          var j: [String: Any] = [
            "x": Double(pos.x), "y": Double(pos.y), "z": Double(pos.z),
          ]
          if let img = try? obs.pointInImage(name) {
            // Vision uses bottom-left origin; flip to top-left for overlays.
            j["px"] = Double(img.x)
            j["py"] = 1.0 - Double(img.y)
          }
          joints[key] = j
        }
        frame["joints"] = joints
        frame["confidence"] = Double(obs.confidence)
        if obs.bodyHeight.isFinite { frame["bodyHeight"] = Double(obs.bodyHeight) }
      }
      frames.append(frame)
    }
    reader.cancelReading()

    let payload: [String: Any] = [
      "sourceFps": nominal,
      "sampledFps": nominal / Double(stride),
      "frames": frames,
    ]
    let data = try JSONSerialization.data(withJSONObject: payload)
    return String(data: data, encoding: .utf8) ?? "{}"
  }

  private static func orientation(for t: CGAffineTransform) -> CGImagePropertyOrientation {
    if t.a == 0 && t.b == 1 && t.c == -1 && t.d == 0 { return .right }  // portrait
    if t.a == 0 && t.b == -1 && t.c == 1 && t.d == 0 { return .left }   // portrait upside-down
    if t.a == -1 && t.d == -1 { return .down }                          // landscape flipped
    return .up
  }
}
