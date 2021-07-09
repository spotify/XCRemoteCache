import Foundation

/// Writes to a file only if the existing content of a file doesn't exist or its content doesn't match
class LazyFileAccessor: FileAccessor {
    private let accessor: FileAccessor

    init(fileAccessor: FileAccessor) {
        accessor = fileAccessor
    }

    func write(toPath path: String, contents: Data?) throws {
        guard let fileContent = try accessor.contents(atPath: path) else {
            try accessor.write(toPath: path, contents: contents)
            return
        }
        guard fileContent != contents else {
            // Files content match - no need to write it to a file
            return
        }
        try accessor.write(toPath: path, contents: contents)
    }

    func removeItem(atPath path: String) throws {
        try accessor.removeItem(atPath: path)
    }

    func contents(atPath path: String) throws -> Data? {
        return try accessor.contents(atPath: path)
    }

    func fileExists(atPath path: String) -> Bool {
        return accessor.fileExists(atPath: path)
    }
}
