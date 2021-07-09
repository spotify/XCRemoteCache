import Foundation

/// DirAccessor composer that uses custom file accessor and dir scanner
class DirAccessorComposer: DirAccessor {
    private let fileAccessor: FileAccessor
    private let dirScanner: DirScanner

    init(fileAccessor: FileAccessor, dirScanner: DirScanner) {
        self.fileAccessor = fileAccessor
        self.dirScanner = dirScanner
    }

    func write(toPath: String, contents: Data?) throws {
        try fileAccessor.write(toPath: toPath, contents: contents)
    }

    func removeItem(atPath path: String) throws {
        try fileAccessor.removeItem(atPath: path)
    }

    func contents(atPath path: String) throws -> Data? {
        try fileAccessor.contents(atPath: path)
    }

    func fileExists(atPath path: String) -> Bool {
        fileAccessor.fileExists(atPath: path)
    }

    func itemType(atPath path: String) throws -> ItemType {
        try dirScanner.itemType(atPath: path)
    }

    func items(at dir: URL) throws -> [URL] {
        try dirScanner.items(at: dir)
    }
}
