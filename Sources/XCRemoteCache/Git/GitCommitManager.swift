import Foundation

/// Manages a storage for a remote-cache enabled commit
protocol GitCommitManager {
    func readCacheCommit() throws -> String
}

/// Manages a commit on in a file
class FileBackedGitCommitManager: GitCommitManager {
    private let file: URL

    init(_ file: URL) {
        self.file = file
    }

    func readCacheCommit() throws -> String {
        return try String(contentsOf: file).trim()
    }
}
