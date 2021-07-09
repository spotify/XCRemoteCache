import Foundation

/// Protocol that controls global (cross-targets) remote cache status
protocol GlobalCacheSwitcher {
    /// Enables remote cache for a specific commit sha
    /// - Parameter sha: sha of a commit
    func enable(sha: String) throws
    /// Fully disables remote cache
    func disable() throws
}

/// Controls remote cache status using an on-disk file
class FileGlobalCacheSwitcher: GlobalCacheSwitcher {
    private let filePath: String
    private let fileAccessor: FileAccessor

    init(_ file: URL, fileAccessor: FileAccessor) {
        filePath = file.path
        self.fileAccessor = fileAccessor
    }

    func enable(sha: String) throws {
        let shaData = sha.data(using: .utf8)!
        try fileAccessor.write(toPath: filePath, contents: shaData)
    }

    /// Disables remote cache by saving an empty file
    /// Note: This section doesn't need to acquire a lock to write. Non-empty content is set only in the
    /// `xcprepare`, that is always run exclusively. All other commands that run in parallel can only empty that file
    func disable() throws {
        if fileAccessor.fileExists(atPath: filePath) {
            try fileAccessor.write(toPath: filePath, contents: Data())
        }
    }
}
