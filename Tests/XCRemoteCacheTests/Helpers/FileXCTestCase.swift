import XCTest

/// Helper class that prepares an empty, source-file exclusive directory
/// Warning: Derived classes should call `try super.tearDownWithError()` if override `tearDownWithError` function
class FileXCTestCase: XCTestCase {
    private(set) var workingDirectory: URL?
    let fileManager = FileManager.default


    @discardableResult
    func prepareTempDir(_ dirKey: String = #file) throws -> URL {
        if let dir = workingDirectory {
            return dir
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(dirKey).resolvingSymlinksInPath()
        // Make sure the potentially dirty dir is removed
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        workingDirectory = url
        return url
    }

    private func cleanupFiles() throws {
        guard let dir = workingDirectory else {
            return
        }
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
        }
    }

    override func tearDownWithError() throws {
        try cleanupFiles()
        try super.tearDownWithError()
    }
}
