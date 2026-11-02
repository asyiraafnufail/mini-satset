import AppKit
import CoreImage

final class QRCodeEngine {
    static let shared = QRCodeEngine()
    private let context = CIContext(options: nil)

    /// Generates a sharp, high-contrast QR code NSImage with a white quiet zone.
    func generateQRCode(from text: String, size: CGFloat = 256) -> NSImage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputCIImage = filter.outputImage else { return nil }
        let extent = outputCIImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        // Quiet zone padding around matrix
        let padding: CGFloat = 16
        let matrixSize = size - (padding * 2)
        let scale = matrixSize / extent.width

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledCIImage = outputCIImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }

        let finalImage = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()

            let drawRect = NSRect(x: padding, y: padding, width: matrixSize, height: matrixSize)
            let qrNSImage = NSImage(cgImage: cgImage, size: NSSize(width: matrixSize, height: matrixSize))
            qrNSImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            return true
        }

        return finalImage
    }

    /// Detects QR code content from an image file at URL.
    func detectQRCode(from url: URL) -> String? {
        guard let ciImage = CIImage(contentsOf: url) else { return nil }
        return decode(ciImage: ciImage)
    }

    /// Detects QR code content from an in-memory NSImage.
    func detectQRCode(from image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else { return nil }
        return decode(ciImage: ciImage)
    }

    private func decode(ciImage: CIImage) -> String? {
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: context,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        return features?.first?.messageString
    }
}
