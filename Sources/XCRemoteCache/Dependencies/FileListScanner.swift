import Foundation

protocol FileListScanner {
    /// Returns true if the url is present in the file list
    func contains(_ url: URL) throws -> Bool
}

/// Finds file on a list of files provied by ListReader
class FileListScannerImpl: FileListScanner {
    private let fileList: ListReader
    private let caseSensitive: Bool

    init(_ fileList: ListReader, caseSensitive: Bool) {
        self.fileList = fileList
        self.caseSensitive = caseSensitive
    }

    func contains(_ url: URL) throws -> Bool {
        if caseSensitive {
            return try fileList.listFilesURLs().contains(url)
        }
        let lowerCasePath = url.path.lowercased()
        return try fileList.listFilesURLs().lazy.contains { element in
            element.path.lowercased() == lowerCasePath
        }
    }
}
