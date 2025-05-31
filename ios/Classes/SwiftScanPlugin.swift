import Flutter
import UIKit
import Vision

public class SwiftScanPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "chavesgu/scan", binaryMessenger: registrar.messenger())
    let instance = SwiftScanPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    registrar.register(ScanViewFactory(registrar: registrar), withId: "chavesgu/scan_view");
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
  if call.method == "getPlatformVersion" {
    result("iOS " + UIDevice.current.systemVersion)
  } else if call.method == "parse" {
    let path = call.arguments as! String
    if let features = self.detectQRCode(UIImage(contentsOfFile: path)), !features.isEmpty {
      if let data = features.first as? CIQRCodeFeature, let message = data.messageString {
        result([
          "value": message,
          "isBarcode": false
        ])
      } else {
        result(nil)
      }
    } else {
      self.detectBarCode(UIImage(contentsOfFile: path), result: result)
    }
  }
}
  
  private func detectQRCode(_ image: UIImage?) -> [CIFeature]? {
    if let image = image, let ciImage = CIImage.init(image: image){
      var options: [String: Any];
      let context = CIContext();
      options = [CIDetectorAccuracy: CIDetectorAccuracyHigh];
      let qrDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: context, options: options);
      if ciImage.properties.keys.contains((kCGImagePropertyOrientation as String)){
        options = [CIDetectorImageOrientation: ciImage.properties[(kCGImagePropertyOrientation as String)] ?? 1];
      } else {
        options = [CIDetectorImageOrientation: 1];
      }
      let features = qrDetector?.features(in: ciImage, options: options);
      return features;
    }
    return nil
  }
  
  private func detectBarCode(_ image: UIImage?, result: @escaping FlutterResult) {
    if let image = image, let ciImage = CIImage(image: image), #available(iOS 11.0, *) {
      var requestHandler: VNImageRequestHandler
      if ciImage.properties.keys.contains(kCGImagePropertyOrientation as String) {
        requestHandler = VNImageRequestHandler(
          ciImage: ciImage,
          orientation: CGImagePropertyOrientation(
            rawValue: ciImage.properties[kCGImagePropertyOrientation as String] as? UInt32 ?? 1
          ) ?? .up,
          options: [:]
        )
      } else {
        requestHandler = VNImageRequestHandler(ciImage: ciImage, orientation: .up, options: [:])
      }
  
      let request = VNDetectBarcodesRequest { (request, error) in
        var payload: String? = nil
        if let observations = request.results as? [VNBarcodeObservation], let first = observations.first {
          payload = first.payloadStringValue
        }
  
        DispatchQueue.main.async {
          if let payload = payload {
            result([
              "value": payload,
              "isBarcode": true
            ])
          } else {
            result(nil)
          }
        }
      }
  
      DispatchQueue.global(qos: .background).async {
        do {
          try requestHandler.perform([request])
        } catch {
          DispatchQueue.main.async {
            result(nil)
          }
        }
      }
    } else {
      result(nil)
    }
  }
}
