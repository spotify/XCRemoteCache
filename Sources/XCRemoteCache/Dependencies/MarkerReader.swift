import Foundation

/// Reads a list of files from a marker file
class FileMarkerReader: ListReader {
    private let file: URL
    private let fileManager: FileManager
    private var cachedFiles: [URL]?

    init(_ file: URL, fileManager: FileManager) {
        self.file = file
        self.fileManager = fileManager
    }

    func listFilesURLs() throws -> [URL] {
        if let cachedResponse = cachedFiles {
            return cachedResponse
        }
        // Skipping first marker line `dependencies: //`
        let fileLines = try String(contentsOf: file).split(separator: "\n").dropFirst()
        let files = fileLines.map { line in
            line.replacingOccurrences(of: FileMarkerWriter.delimiter, with: "")
        }
        let filesURLs = files.map(URL.init(fileURLWithPath:))
        cachedFiles = filesURLs
        return filesURLs
    }

    func canRead() -> Bool {
        return fileManager.fileExists(atPath: file.path)
    }
}
