import Foundation
@testable import XCRemoteCache

class FileManagerFake: FileManager {
    var shouldReturnContentsOfFile = false
    override func contents(atPath path: String) -> Data? {
        return shouldReturnContentsOfFile ? Data() : nil
    }
}
