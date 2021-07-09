import Foundation

/// Provides files write access
protocol FileWriter {
    /// Writes data bytes to a file
    /// - Parameters:
    ///   - toPath: path of the file
    ///   - content: content or `nil` if the file should be empty
    func write(toPath: String, contents: Data?) throws

    /// Deletes a file at given path
    func removeItem(atPath path: String) throws
}

/// Provides files read access
protocol FileReader {
    /// Reads content of a file
    /// - Parameters:
    ///   - atPath: path of the file
    /// - Returns content of a file or `nil` if the file doesn't exist
    /// - Throws when accessing a file failed
    func contents(atPath path: String) throws -> Data?

    /// Returns true if a file at given path exists
    /// - Parameter atPath: path of the file
    func fileExists(atPath path: String) -> Bool
}

typealias FileAccessor = FileWriter & FileReader

extension FileManager: FileWriter {
    func write(toPath path: String, contents: Data?) throws {
        try spt_writeToFile(atPath: path, contents: contents)
    }
}

extension FileManager: FileReader {}
