import Foundation

/// Type of an item placed in a directory
enum ItemType {
    case file
    case dir
    case nonExisting
}

protocol DirScanner {
    /// Returns a type an item
    /// - Parameter atPath: path of a file
    func itemType(atPath path: String) throws -> ItemType

    /// Returns all items in a directory (shallow search)
    /// - Parameter at: url of an existing directory to search
    /// - Throws: an error if dir doesn't exist or I/O error
    func items(at dir: URL) throws -> [URL]
}

typealias DirAccessor = FileAccessor & DirScanner

extension FileManager: DirScanner {
    func itemType(atPath path: String) throws -> ItemType {
        var isDir: ObjCBool = false
        guard fileExists(atPath: path, isDirectory: &isDir) else {
            // dir doesn't exist
            return .nonExisting
        }
        return isDir.boolValue ? .dir : .file
    }

    func items(at dir: URL) throws -> [URL] {
        // FileManager is not capable of listing files if the URL includes symlinks
        let resolvedDir = dir.resolvingSymlinksInPath()
        return try contentsOfDirectory(at: resolvedDir, includingPropertiesForKeys: nil, options: [])
    }
}
