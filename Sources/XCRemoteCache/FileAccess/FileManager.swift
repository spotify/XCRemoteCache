import Foundation

enum FileManagerError: Error {
    case fileMismatch(URL)
    case fileCreationFailed(URL)
}

extension FileManager {
    func spt_writeToFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]? = nil) throws {
        let fileURL = URL(fileURLWithPath: path)
        let fileDirectory = fileURL.deletingLastPathComponent()

        var isDir: ObjCBool = false
        if fileExists(atPath: fileDirectory.path, isDirectory: &isDir) {
            guard isDir.boolValue else {
                errorLog("File mismatched, \(fileDirectory) expected to be a directory")
                throw FileManagerError.fileMismatch(fileDirectory)
            }
        } else {
            try createDirectory(at: fileDirectory, withIntermediateDirectories: true, attributes: nil)
        }
        let result = createFile(atPath: path, contents: data, attributes: attr)
        if !result {
            errorLog("File creation failed at: \(fileURL.description)")
            throw FileManagerError.fileCreationFailed(fileURL)
        }
    }

    func spt_forceLinkItem(at srcURL: URL, to dstURL: URL) throws {
        let destLink = try? destinationOfSymbolicLink(atPath: dstURL.path)
        if destLink == srcURL.path {
            // Already linked to the right destination
            return
        }
        if fileExists(atPath: dstURL.path) {
            try removeItem(at: dstURL)
        } else {
            let parentDir = dstURL.deletingLastPathComponent()
            if !fileExists(atPath: parentDir.path) {
                try createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
            }
        }
        try linkItem(at: srcURL, to: dstURL)
    }

    /// links symbolically destination location to the linkURL
    /// Supports creating intermediate directories and
    /// overrides previous file/link at the destination
    func spt_forceSymbolicLink(at linkURL: URL, withDestinationURL dstURL: URL) throws {
        if fileExists(atPath: linkURL.path) {
            try removeItem(at: linkURL)
        }
        try createDirectory(at: linkURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        try createSymbolicLink(at: linkURL, withDestinationURL: dstURL)
    }


    /// Returns symbolic link destination or a file itself if not a symlink
    /// Throws an error when the file doesn't exists
    func spt_followSymbolicLink(_ url: URL) throws -> URL {
        // For non-existing `url` file, an error is thrown by `resourceValues`
        let resourceValue = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        if resourceValue.isSymbolicLink == true {
            return try URL(fileURLWithPath: destinationOfSymbolicLink(atPath: url.path))
        }
        // Not a symlink
        return url
    }

    /// Copies file with the override
    func spt_forceCopyItem(at srcURL: URL, to dstURL: URL) throws {
        try spt_deleteItem(at: dstURL)
        try copyItem(at: srcURL, to: dstURL)
    }

    /// Removes file/dir if it exists
    /// - Throws: An error if deletion was unsuccessful
    func spt_deleteItem(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}
