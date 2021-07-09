import Foundation
@testable import XCRemoteCache

class ListReaderFake: ListReader {
    private let files: [URL]?
    init(files: [URL]?) {
        self.files = files
    }

    func listFilesURLs() throws -> [URL] {
        return try files.unwrap()
    }

    func canRead() -> Bool {
        return files != nil
    }
}
