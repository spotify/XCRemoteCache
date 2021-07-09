import Foundation

/// Manages file attributes (e.g. modification, creation date)
public protocol Touch {
    /// Updates file modification date or creates empty one (if not existing)
    func touch() throws
}

public class FileTouch: Touch {
    private let filePath: String
    private let fileManager: FileManager

    public init(_ file: URL, fileManager: FileManager) {
        filePath = file.path
        self.fileManager = fileManager
    }

    public func touch() throws {
        if fileManager.fileExists(atPath: filePath) {
            var attributes = try fileManager.attributesOfFileSystem(forPath: filePath)
            attributes[.modificationDate] = Date()
            try fileManager.setAttributes(attributes, ofItemAtPath: filePath)
        } else {
            fileManager.createFile(atPath: filePath, contents: nil, attributes: nil)
        }
    }
}
