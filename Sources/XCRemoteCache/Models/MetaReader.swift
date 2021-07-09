import Foundation

enum MetaReaderError: Error {
    /// Missing file that should contain the meta
    case missingFile(URL)
}

/// Parses and provides `MainArtifactMeta`. Supports reading from a disk or directly from provided data representation
protocol MetaReader {
    /// Reads from a local disk location
    /// - Parameter localFile: location of the file to parse
    func read(localFile: URL) throws -> MainArtifactMeta
    /// Reads from a data representation
    /// - Parameter data: meta representation
    func read(data: Data) throws -> MainArtifactMeta
}

/// Parses `MainArtifactMeta` from a JSON representation
class JsonMetaReader: MetaReader {
    private let decoder = JSONDecoder()
    private let fileAccessor: FileAccessor

    init(fileAccessor: FileAccessor) {
        self.fileAccessor = fileAccessor
    }

    func read(localFile: URL) throws -> MainArtifactMeta {
        guard let data = try fileAccessor.contents(atPath: localFile.path) else {
            throw MetaReaderError.missingFile(localFile)
        }
        return try read(data: data)
    }

    func read(data: Data) throws -> MainArtifactMeta {
        return try decoder.decode(MainArtifactMeta.self, from: data)
    }
}
