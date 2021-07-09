import Foundation

/// Verifies if the filename should be always disallowed/allowed. If a filename does not match with allowed/disallowed
/// entries, the decision is handled by the underlying `scanner`
/// Note: disallowed filenames have higher priorities than allowed ones
class ExceptionsFilteredFileListScanner: FileListScanner {
    private let listScanner: FileListScanner
    private let allowedFilenames: [String]
    private let disallowedFilenames: [String]

    /// Default initializer that specifies disallowed and allowed filenames (including an extention)
    /// Valid filenames: ['file.swift', 'file.m']
    /// Invalid filenames: ['somePath/file.swift', '/absolutePath/file.m']
    ///
    /// - Parameters:
    ///   - allowedFilenames: a list of filenames which should always be allowed
    ///   - disallowedFilenames: a list of filenames which should always be disallowed
    ///   - scanner: underlying scanner that decides if non of allowed/disallowed pattern matches
    init(allowedFilenames: [String], disallowedFilenames: [String], scanner: FileListScanner) {
        self.allowedFilenames = allowedFilenames
        self.disallowedFilenames = disallowedFilenames
        listScanner = scanner
    }

    func contains(_ url: URL) throws -> Bool {
        let filename = url.lastPathComponent
        if disallowedFilenames.contains(filename) {
            return false
        }
        if allowedFilenames.contains(filename) {
            return true
        }
        return try listScanner.contains(url)
    }
}
