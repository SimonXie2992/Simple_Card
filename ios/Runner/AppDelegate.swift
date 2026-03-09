import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var cameraChannel: FlutterMethodChannel?
  private let cameraService = CameraService()
  
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    if let controller = window?.rootViewController as? FlutterViewController {
      cameraChannel = FlutterMethodChannel(name: "com.simon.simplecard/camera", binaryMessenger: controller.binaryMessenger)
      cameraChannel?.setMethodCallHandler({ [weak self] (call, result) in
        guard let self = self else { return }
        
        switch call.method {
        case "processImage":
          if let args = call.arguments as? FlutterStandardTypedData {
            self.cameraService.processImageData(args.data, result: result)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected image data as Uint8List", details: nil))
          }
        case "generatePdf":
          if let args = call.arguments as? [String] {
            self.cameraService.generatePdf(from: args, result: result)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected list of image paths", details: nil))
          }
        case "detectRectangleLive":
          if let args = call.arguments as? [String: Any],
             let bytesData = args["bytes"] as? FlutterStandardTypedData,
             let width = args["width"] as? Int,
             let height = args["height"] as? Int,
             let bytesPerRow = args["bytesPerRow"] as? Int {
            self.cameraService.detectRectangleLive(bytesData.data, width: width, height: height, bytesPerRow: bytesPerRow, result: result)
          } else {
            result(nil)
          }
        case "processCapture":
          if let args = call.arguments as? String {
            self.cameraService.processCapture(imagePath: args, result: result)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected image path string", details: nil))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      })
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
