import Foundation

/// Writer for dependencies in a Make-format (.d file)
public protocol DependenciesWriter {
    /// Saves a list of dependencies for a set of files
    /// - Parameter dependencies: The dictionary where filepath is a key and an array it
    /// its dependencies filepath are values
    func write(dependencies: [String: [String]]) throws
    /// Saves a XCRetemoCache custom dependencies format (valid .d format) that indicates skipping that phase up,
    /// if the remote commit is equal to the provided `skipForSha`
    func write(skipForSha: String) throws
}

extension DependenciesWriter {
    /// Write dependency list for a single file
    func write(file: URL, dependencies: [URL]) throws {
        try write(dependencies: [file.path: dependencies.map { $0.path }])
    }
}

public class FileDependenciesWriter: DependenciesWriter {
    static let skipForShaKey = "skipForSha"

    private let file: URL

    public init(_ file: URL, accessor: FileManager) {
        self.file = file
    }

    public func write(dependencies: [String: [String]]) throws {
        var content = ""
        for (file, deps) in dependencies {
            content.append(file + ": ")
            content.append(deps.joined(separator: " "))
            content.append("\n")
        }
        try content.write(to: file, atomically: true, encoding: .utf8)
    }

    public func write(skipForSha sha: String) throws {
        try write(dependencies: [Self.skipForShaKey: [sha]])
    }
}


extension DependenciesWriter {
    func writeGeneric(dependencies: [URL]) throws {
        try write(dependencies: ["dependencies": dependencies.map { $0.path }])
    }
}
