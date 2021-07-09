import Foundation
@testable import XCRemoteCache

enum FileAccessorFakeError: Error {
    case itemDoesntExist
}

class FileAccessorFake: FileAccessor {
    enum Mode {
        case normal
        case strict
    }

    private var storage: [String: (content: Data?, mdate: Date)] = [:]
    private let mode: Mode

    init(mode: Mode) {
        self.mode = mode
    }

    func contents(atPath path: String) throws -> Data? {
        return storage[path]?.content
    }

    func fileExists(atPath path: String) -> Bool {
        return storage.keys.contains(path)
    }

    func write(toPath path: String, contents: Data?) throws {
        storage[path] = (contents, Date())
    }

    func removeItem(atPath path: String) throws {
        if mode == .strict && storage[path] == nil {
            throw FileAccessorFakeError.itemDoesntExist
        }
        storage[path] = nil
    }

    func fileMDate(atPath path: String) -> Date? {
        return storage[path]?.mdate
    }
}
