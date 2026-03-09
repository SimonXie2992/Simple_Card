import UIKit
import Flutter
import Vision
import CoreImage

class CameraService {
    
    // MARK: - PDF Generation
    
    func generatePdf(from imagePaths: [String], result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, .zero, nil)
            for path in imagePaths {
                guard let image = UIImage(contentsOfFile: path) else { continue }
                let pageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
                UIGraphicsBeginPDFPageWithInfo(pageRect, nil)
                image.draw(in: pageRect)
            }
            UIGraphicsEndPDFContext()
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let fileName = "scan_\(dateFormatter.string(from: Date())).pdf"
            let pdfPath = documentsPath.appendingPathComponent(fileName)
            do {
                try pdfData.write(to: pdfPath, options: .atomic)
                DispatchQueue.main.async { result(pdfPath.path) }
            } catch {
                DispatchQueue.main.async { result(FlutterError(code: "PDF_ERR", message: error.localizedDescription, details: nil)) }
            }
        }
    }
    
    // MARK: - OCR
    
    func processImageData(_ data: Data, result: @escaping FlutterResult) {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            result(FlutterError(code: "IO_ERR", message: "Failed to decode image data", details: nil))
            return
        }
        performOCR(on: cgImage, result: result)
    }
    
    private func performOCR(on cgImage: CGImage, result: @escaping FlutterResult) {
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                DispatchQueue.main.async { result(FlutterError(code: "OCR_ERR", message: error.localizedDescription, details: nil)) }
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                DispatchQueue.main.async { result("No text detected") }
                return
            }
            
            let mappedObservations: [[String: Any]] = observations.compactMap { obs in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                // Vision bounding boxes have origin at bottom-left, but mapped to 0-1 bounds 
                // We return as is, and Flutter will flip Y if needed
                return [
                    "text": candidate.string,
                    "rect": [
                        "x": Double(obs.boundingBox.origin.x),
                        "y": Double(obs.boundingBox.origin.y),
                        "w": Double(obs.boundingBox.size.width),
                        "h": Double(obs.boundingBox.size.height)
                    ],
                    "confidence": Double(candidate.confidence)
                ]
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: mappedObservations, options: []),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                DispatchQueue.main.async { result(jsonString) }
            } else {
                DispatchQueue.main.async { result("No text detected") }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "ja", "en"]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do { try handler.perform([request]) }
            catch { DispatchQueue.main.async { result(FlutterError(code: "EXEC_ERR", message: error.localizedDescription, details: nil)) } }
        }
    }
    
    // MARK: - Live Rectangle Detection (from BGRA camera stream)
    
    func detectRectangleLive(_ data: Data, width: Int, height: Int, bytesPerRow: Int, result: @escaping FlutterResult) {
        // Run on userInteractive queue for lower latency
        DispatchQueue.global(qos: .userInteractive).async {
            // Create CGImage from raw bytes efficiently
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let provider = CGDataProvider(data: data as CFData),
                  let cgImage = CGImage(
                    width: width, height: height,
                    bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: bytesPerRow, space: colorSpace,
                    bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
                    provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
                  ) else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            
            // Dynamic orientation based on frame dimensions
            // Camera sensor on iOS outputs landscape frames (width > height)
            // .right rotates 90° CW to portrait for Vision processing
            // If frame is already portrait (e.g., locked orientation applied to raw frames), use .up
            let orientation: CGImagePropertyOrientation = width > height ? .right : .up
            
            let request = VNDetectRectanglesRequest()
            request.minimumConfidence = 0.5
            request.maximumObservations = 1
            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 3.0
            request.quadratureTolerance = 30 // Slightly wider tolerance for better detection range
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do { try handler.perform([request]) } catch {
                DispatchQueue.main.async { result(nil) }
                return
            }
            
            guard let observations = request.results as? [VNRectangleObservation],
                  let rect = observations.first else {
                DispatchQueue.main.async { result(nil) }
                return
            }
            
            // Return corners + frame info so Flutter can compute accurate mapping
            let corners: [String: Double] = [
                "topLeftX": Double(rect.topLeft.x), "topLeftY": Double(rect.topLeft.y),
                "topRightX": Double(rect.topRight.x), "topRightY": Double(rect.topRight.y),
                "bottomLeftX": Double(rect.bottomLeft.x), "bottomLeftY": Double(rect.bottomLeft.y),
                "bottomRightX": Double(rect.bottomRight.x), "bottomRightY": Double(rect.bottomRight.y),
                "frameWidth": Double(width), "frameHeight": Double(height),
                "isRotated": width > height ? 1.0 : 0.0, // Whether .right rotation was applied
            ]
            DispatchQueue.main.async { result(corners) }
        }
    }
    
    // MARK: - Process Capture (detect rectangle + perspective correct + classify)
    
    func processCapture(imagePath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let uiImage = UIImage(contentsOfFile: imagePath),
                  let cgImage = uiImage.cgImage else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "IO_ERR", message: "Failed to load image", details: nil))
                }
                return
            }
            
            // Detect rectangle
            let request = VNDetectRectanglesRequest()
            request.minimumConfidence = 0.6
            request.maximumObservations = 1
            request.minimumAspectRatio = 0.3
            request.maximumAspectRatio = 3.0
            request.quadratureTolerance = 25
            
            var orientation: CGImagePropertyOrientation = .up
            switch uiImage.imageOrientation {
            case .right: orientation = .right
            case .left: orientation = .left
            case .down: orientation = .down
            case .up: orientation = .up
            default: orientation = .right // Default for camera capture usually
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            
            // Default response on failure
            let defaultResponse: [String: Any] = ["type": "document", "correctedPath": imagePath] // Default to doc if detection fails
            
            do { try handler.perform([request]) } catch {
                DispatchQueue.main.async { result(defaultResponse) }
                return
            }
            
            guard let observations = request.results as? [VNRectangleObservation],
                  let rect = observations.first else {
                DispatchQueue.main.async { result(defaultResponse) }
                return
            }
            
            // Perspective correction using CIImage
            let ciImage = CIImage(cgImage: cgImage).oriented(forExifOrientation: Int32(orientation.rawValue))
            let imageSize = ciImage.extent.size
            
            let topLeft = CGPoint(x: CGFloat(rect.topLeft.x) * imageSize.width,
                                  y: CGFloat(rect.topLeft.y) * imageSize.height)
            let topRight = CGPoint(x: CGFloat(rect.topRight.x) * imageSize.width,
                                   y: CGFloat(rect.topRight.y) * imageSize.height)
            let bottomLeft = CGPoint(x: CGFloat(rect.bottomLeft.x) * imageSize.width,
                                     y: CGFloat(rect.bottomLeft.y) * imageSize.height)
            let bottomRight = CGPoint(x: CGFloat(rect.bottomRight.x) * imageSize.width,
                                      y: CGFloat(rect.bottomRight.y) * imageSize.height)
            
            let corrected = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
                "inputTopLeft": CIVector(cgPoint: topLeft),
                "inputTopRight": CIVector(cgPoint: topRight),
                "inputBottomLeft": CIVector(cgPoint: bottomLeft),
                "inputBottomRight": CIVector(cgPoint: bottomRight),
            ])
            
            // ── Image Enhancement: brighten & whiten for clean scan look ──
            let enhanced = corrected
                .applyingFilter("CIColorControls", parameters: [
                    kCIInputBrightnessKey: 0.05,          // Slight brightness boost
                    kCIInputContrastKey: 1.15,             // Sharper contrast
                    kCIInputSaturationKey: 0.9,            // Slightly desaturate for cleaner look
                ])
                .applyingFilter("CIHighlightShadowAdjust", parameters: [
                    "inputShadowAmount": 0.3,              // Lift shadows (whitening)
                    "inputHighlightAmount": 1.0,           // Keep highlights
                ])
                .applyingFilter("CIExposureAdjust", parameters: [
                    kCIInputEVKey: 0.3,                    // Slight exposure boost
                ])
            
            // Classify by corrected aspect ratio
            let correctedAR = corrected.extent.width / corrected.extent.height
            let type = (correctedAR > 1.45 || correctedAR < 0.68) ? "card" : "document"
            
            // Render enhanced image
            let context = CIContext()
            guard let correctedCG = context.createCGImage(enhanced, from: enhanced.extent) else {
                DispatchQueue.main.async { result(["type": type, "correctedPath": imagePath]) }
                return
            }
            
            let correctedUI = UIImage(cgImage: correctedCG)
            guard let jpegData = correctedUI.jpegData(compressionQuality: 0.95) else {
                DispatchQueue.main.async { result(["type": type, "correctedPath": imagePath]) }
                return
            }
            
            let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let correctedPath = docsPath.appendingPathComponent("corrected_\(Int(Date().timeIntervalSince1970)).jpg")
            do {
                try jpegData.write(to: correctedPath, options: .atomic)
                DispatchQueue.main.async { result(["type": type, "correctedPath": correctedPath.path]) }
            } catch {
                DispatchQueue.main.async { result(["type": type, "correctedPath": imagePath]) }
            }
        }
    }
}
