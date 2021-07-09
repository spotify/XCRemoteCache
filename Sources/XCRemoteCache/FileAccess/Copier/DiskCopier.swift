import Foundation

/// Copier that moves files between two locations
protocol DiskCopier {
    func copy(file source: URL, destination: URL) throws
}

extension DiskCopier {
    /// Moves item to the directory with the same name as in the source (mimic the `cp` behaviour)
    func copy(file source: URL, directory: URL) throws {
        let fileName = source.lastPathComponent
        let destination = directory.appendingPathComponent(fileName)
        try copy(file: source, destination: destination)
    }
}
