import AppKit
import Vision

final class OCREngine {
    static let shared = OCREngine()

    /// Recognizes text from image Data using Apple's Vision framework (100% on-device Neural Engine).
    func recognizeText(from data: Data, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            autoreleasepool {
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        DispatchQueue.main.async { completion(.failure(error)) }
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        DispatchQueue.main.async { completion(.success("")) }
                        return
                    }

                    let lines = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }

                    let resultText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    DispatchQueue.main.async {
                        completion(.success(resultText))
                    }
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(data: data, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            }
        }
    }

    /// Recognizes text from an image file at URL off the main thread.
    func recognizeText(from fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "OCREngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read image data."])))
                }
                return
            }
            self.recognizeText(from: data, completion: completion)
        }
    }

    /// Launches native macOS interactive rectangle capture, runs OCR, and cleans up temp files.
    func captureScreenAndRecognize(completion: @escaping (Result<String?, Error>) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("mini-satset-ocr-\(UUID().uuidString).png")

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-x", "-s", tempFile.path]

            do {
                try process.run()
                process.waitUntilExit()

                defer {
                    try? FileManager.default.removeItem(at: tempFile)
                }

                guard FileManager.default.fileExists(atPath: tempFile.path),
                      let data = try? Data(contentsOf: tempFile),
                      !data.isEmpty else {
                    // User canceled capture (pressed Escape or clicked without drag)
                    DispatchQueue.main.async { completion(.success(nil)) }
                    return
                }

                self.recognizeText(from: data) { result in
                    switch result {
                    case .success(let text):
                        completion(.success(text))
                    case .failure(let err):
                        completion(.failure(err))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}
