import Foundation

/// Manage marker file entries
protocol MarkerWriter {
    /// Saves all dependencies
    func enable(dependencies: [URL]) throws
    /// Disables mode marker
    func disable() throws
}

/// Saves a marker using a format matching .d one
class FileMarkerWriter: MarkerWriter {
    static let delimiter = " \\"
    private let filePath: String
    private let fileAccessor: FileAccessor

    init(_ file: URL, fileAccessor: FileAccessor) {
        filePath = file.path
        self.fileAccessor = fileAccessor
    }

    func enable(dependencies: [URL]) throws {
        let lines = ["dependencies: "] + dependencies.map { $0.path }
        let fileContent = lines.joined(separator: "\(Self.delimiter)\n")
        try fileAccessor.write(toPath: filePath, contents: fileContent.data(using: .utf8))
    }

    func disable() throws {
        if fileAccessor.fileExists(atPath: filePath) {
            try fileAccessor.removeItem(atPath: filePath)
        }
    }
}

/// Marker Writer that does nothing
class NoopMarkerWriter: MarkerWriter {
    init(_ file: URL, fileManager: FileManager) {}

    func enable(dependencies: [URL]) throws {}

    func disable() throws {}
}
