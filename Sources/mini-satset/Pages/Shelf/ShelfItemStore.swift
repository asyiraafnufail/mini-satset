import Foundation

struct ShelfText: Identifiable, Equatable {
    let id: UUID
    let content: String
    let createdAt: Date

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.createdAt = Date()
    }

    var remainingSeconds: Int {
        let elapsed = Int(Date().timeIntervalSince(createdAt))
        return max(0, 300 - elapsed)
    }

    var isExpired: Bool {
        return remainingSeconds <= 0
    }
}

struct ShelfFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let fileName: String
    let fileSizeFormatted: String
    let createdAt: Date

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.fileName = url.lastPathComponent
        self.createdAt = Date()

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useKB, .useBytes]
            formatter.countStyle = .file
            self.fileSizeFormatted = formatter.string(fromByteCount: size)
        } else {
            self.fileSizeFormatted = "File"
        }
    }

    var remainingSeconds: Int {
        let elapsed = Int(Date().timeIntervalSince(createdAt))
        return max(0, 300 - elapsed)
    }

    var isExpired: Bool {
        return remainingSeconds <= 0
    }
}

final class ShelfItemStore {
    static let shared = ShelfItemStore()

    private(set) var textItems: [ShelfText] = []
    private(set) var fileItems: [ShelfFile] = []

    private init() {}

    func addText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        purgeExpired()
        textItems.insert(ShelfText(content: trimmed), at: 0)
        if textItems.count > 20 {
            textItems.removeLast()
        }
    }

    func addFileURL(_ url: URL) {
        purgeExpired()
        // Check duplicate
        if !fileItems.contains(where: { $0.url == url }) {
            fileItems.insert(ShelfFile(url: url), at: 0)
            if fileItems.count > 10 {
                fileItems.removeLast()
            }
        }
    }

    func removeText(id: UUID) {
        textItems.removeAll { $0.id == id }
    }

    func removeFile(id: UUID) {
        fileItems.removeAll { $0.id == id }
    }

    func clearAll() {
        textItems.removeAll()
        fileItems.removeAll()
    }

    func purgeExpired() {
        textItems.removeAll { $0.isExpired }
        fileItems.removeAll { $0.isExpired }
    }
}
