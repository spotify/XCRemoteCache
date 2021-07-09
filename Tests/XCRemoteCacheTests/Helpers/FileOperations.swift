import Foundation

/// Testing helper functions that manage files and dirs on a disk
extension FileManager {
    @discardableResult
    func spt_createEmptyFile(_ url: URL) throws -> URL {
        try spt_createFile(url, content: nil)
    }

    @discardableResult
    func spt_createFile(_ url: URL, content: String?) throws -> URL {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
        try spt_ensureDir(url.deletingLastPathComponent())
        let contents = content.flatMap { $0.data(using: .utf8) }
        createFile(atPath: url.path, contents: contents, attributes: nil)
        return url
    }

    func spt_ensureDir(_ url: URL) throws {
        if fileExists(atPath: url.path) {
            return
        }
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    @discardableResult
    func spt_createEmptyDir(_ url: URL) throws -> URL {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }

    func spt_allFilesRecusively(_ url: URL) throws -> [URL] {
        guard fileExists(atPath: url.path) else {
            throw "No directory \(url)"
        }
        let allURLs = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        return try allURLs.reduce([URL]()) { urls, url in
            var isDir: ObjCBool = false
            fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
                return try urls + spt_allFilesRecusively(url)
            }
            return urls + [url.resolvingSymlinksInPath()]
        }
    }
}
