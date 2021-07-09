@testable import XCRemoteCache
import XCTest

class DirAccessorFake: DirAccessor {
    private var memory: [URL: Data] = [:]

    func itemType(atPath path: String) throws -> ItemType {
        if fileExists(atPath: path) {
            return .file
        }
        // iterate all files to see it is a dir
        let isDir = memory.first { fileURL, _ in
            fileURL.path.hasPrefix(path)
        }
        if isDir != nil {
            return .dir
        }
        return .nonExisting
    }

    func items(at dir: URL) throws -> [URL] {
        memory.compactMap { url, _ in
            // compare paths to ignore dir or url's "isDir"
            if url.deletingLastPathComponent().path == dir.path {
                return url
            }
            return nil
        }
    }

    func contents(atPath path: String) throws -> Data? {
        memory[URL(fileURLWithPath: path)]
    }

    func fileExists(atPath path: String) -> Bool {
        memory[URL(fileURLWithPath: path)] != nil
    }

    func write(toPath: String, contents: Data?) throws {
        memory[URL(fileURLWithPath: toPath)] = contents
    }

    func removeItem(atPath path: String) throws {
        memory[URL(fileURLWithPath: path)] = nil
    }
}
