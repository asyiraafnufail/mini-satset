import Foundation
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

enum ConvertError: LocalizedError {
    case unsupportedFormat
    case readFailed
    case writeFailed
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return "Unsupported file format."
        case .readFailed: return "Could not read source file."
        case .writeFailed: return "Could not save converted file."
        case .processFailed(let msg): return msg
        }
    }
}

enum ImageQuality: Int {
    case high = 0       // 100%
    case medium = 1     // 75%
    case compressed = 2 // 50%

    var compressionFactor: CGFloat {
        switch self {
        case .high: return 1.0
        case .medium: return 0.75
        case .compressed: return 0.50
        }
    }
}

enum AudioQuality: Int {
    case original = 0
    case high = 1       // 256k
    case compressed = 2 // 128k

    var bitrate: Int? {
        switch self {
        case .original: return nil
        case .high: return 256000
        case .compressed: return 128000
        }
    }
}

enum FileCategory {
    case image
    case audio
    case unsupported
}

final class ConverterEngine {
    static let shared = ConverterEngine()

    private let supportedImageExts = ["png", "jpg", "jpeg", "heic", "webp", "tiff", "tif"]
    private let supportedAudioExts = ["wav", "mp3", "m4a", "aac", "caf", "aiff"]

    func category(for url: URL) -> FileCategory {
        let ext = url.pathExtension.lowercased()
        if supportedImageExts.contains(ext) {
            return .image
        }
        if supportedAudioExts.contains(ext) {
            return .audio
        }
        return .unsupported
    }

    func availableTargetFormats(for url: URL) -> [String] {
        let cat = category(for: url)
        let current = url.pathExtension.lowercased()

        switch cat {
        case .image:
            let all = ["jpg", "png", "heic", "webp", "tiff"]
            return all.filter { $0 != current }
        case .audio:
            let all = ["m4a", "wav", "caf", "mp3"]
            return all.filter { $0 != current }
        case .unsupported:
            return []
        }
    }

    // MARK: - Image Conversion (Native ImageIO, Hardware Accelerated, No Upscale)

    func convertImage(
        sourceURL: URL,
        targetExt: String,
        quality: ImageQuality,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let readOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, readOptions) else {
                DispatchQueue.main.async { completion(.failure(ConvertError.readFailed)) }
                return
            }

            guard CGImageSourceGetCount(imageSource) > 0,
                  let image = CGImageSourceCreateImageAtIndex(imageSource, 0, readOptions) else {
                DispatchQueue.main.async { completion(.failure(ConvertError.readFailed)) }
                return
            }

            let targetUTI: CFString
            switch targetExt.lowercased() {
            case "jpg", "jpeg":
                targetUTI = "public.jpeg" as CFString
            case "png":
                targetUTI = "public.png" as CFString
            case "heic":
                targetUTI = "public.heic" as CFString
            case "webp":
                targetUTI = "org.webmproject.webp" as CFString
            case "tiff", "tif":
                targetUTI = "public.tiff" as CFString
            default:
                targetUTI = "public.png" as CFString
            }

            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let tempDir = FileManager.default.temporaryDirectory
            let destinationURL = tempDir.appendingPathComponent("\(baseName)-converted.\(targetExt)")

            try? FileManager.default.removeItem(at: destinationURL)

            guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, targetUTI, 1, nil) else {
                DispatchQueue.main.async { completion(.failure(ConvertError.writeFailed)) }
                return
            }

            var options: [CFString: Any] = [:]
            if targetExt.lowercased() != "png" {
                options[kCGImageDestinationLossyCompressionQuality] = quality.compressionFactor as CFNumber
            }

            CGImageDestinationAddImage(destination, image, options as CFDictionary)

            if CGImageDestinationFinalize(destination) {
                DispatchQueue.main.async { completion(.success(destinationURL)) }
            } else {
                DispatchQueue.main.async { completion(.failure(ConvertError.writeFailed)) }
            }
        }
    }

    // MARK: - Audio Conversion (Native CoreAudio / afconvert CLI)

    func convertAudio(
        sourceURL: URL,
        targetExt: String,
        quality: AudioQuality,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let baseName = sourceURL.deletingPathExtension().lastPathComponent
            let tempDir = FileManager.default.temporaryDirectory
            let destinationURL = tempDir.appendingPathComponent("\(baseName)-converted.\(targetExt)")

            try? FileManager.default.removeItem(at: destinationURL)

            var args: [String] = []
            switch targetExt.lowercased() {
            case "m4a":
                args = ["-f", "m4af", "-d", "aac"]
                if let br = quality.bitrate {
                    args += ["-b", "\(br)"]
                }
            case "wav":
                args = ["-f", "WAVE", "-d", "LEI16"]
            case "caf":
                args = ["-f", "caff", "-d", "aac"]
                if let br = quality.bitrate {
                    args += ["-b", "\(br)"]
                }
            case "mp3":
                args = ["-f", "MPG3", "-d", ".mp3"]
                if let br = quality.bitrate {
                    args += ["-b", "\(br)"]
                }
            default:
                args = ["-f", "m4af", "-d", "aac"]
            }

            args += [sourceURL.path, destinationURL.path]

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
            process.arguments = args
            let pipe = Pipe()
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: destinationURL.path) {
                    DispatchQueue.main.async { completion(.success(destinationURL)) }
                } else {
                    let errData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayMsg = (errMsg?.isEmpty == false) ? errMsg! : "Conversion failed."
                    DispatchQueue.main.async { completion(.failure(ConvertError.processFailed(displayMsg))) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}
