import Foundation

struct NetworkResult: Decodable {
    let dl_throughput: Double?
    let ul_throughput: Double?
    let responsiveness: Double?
    let base_rtt: Double?

    var downloadMbps: Double {
        return (dl_throughput ?? 0) / 1_000_000.0
    }

    var uploadMbps: Double {
        return (ul_throughput ?? 0) / 1_000_000.0
    }

    var rpm: Int {
        return Int(responsiveness ?? 0)
    }

    var pingMs: Int {
        return Int(base_rtt ?? 0)
    }
}

final class SpeedTestEngine {
    private var currentProcess: Process?
    private var isRunning: Bool = false

    func startTest(
        onProgress: @escaping (String) -> Void,
        onCompletion: @escaping (Result<NetworkResult, Error>) -> Void
    ) {
        guard !isRunning else { return }
        isRunning = true

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        process.arguments = ["-c"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        currentProcess = process

        onProgress("Testing network via Apple CDN...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                self?.isRunning = false
                self?.currentProcess = nil

                if process.terminationStatus == 0,
                   let result = try? JSONDecoder().decode(NetworkResult.self, from: data) {
                    DispatchQueue.main.async {
                        onCompletion(.success(result))
                    }
                } else {
                    struct NetworkError: LocalizedError {
                        var errorDescription: String? { "Failed to test network. Check your internet connection." }
                    }
                    DispatchQueue.main.async {
                        onCompletion(.failure(NetworkError()))
                    }
                }
            } catch {
                self?.isRunning = false
                self?.currentProcess = nil
                DispatchQueue.main.async {
                    onCompletion(.failure(error))
                }
            }
        }
    }

    func cancelTest() {
        if isRunning, let process = currentProcess {
            process.terminate()
            currentProcess = nil
            isRunning = false
        }
    }
}
