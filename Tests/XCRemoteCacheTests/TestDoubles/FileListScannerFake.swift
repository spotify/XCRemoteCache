import Foundation
@testable import XCRemoteCache

class FileListScannerFake: FileListScanner {
    private let files: [URL]
    init(files: [URL]) {
        self.files = files
    }

    func contains(_ url: URL) throws -> Bool {
        return files.contains(url)
    }
}
