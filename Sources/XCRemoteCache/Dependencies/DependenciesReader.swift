import Foundation
import Yams

enum DependenciesReaderError: Error {
    case readingError
    case invalidFile
    case invalidFormat
}

/// Readers for dependencies for a Make-format (.d) file
public protocol DependenciesReader {
    /// Finds all dependencies paths
    func findDependencies() throws -> [String]
    /// Finds all files that were compiled
    func findInputs() throws -> [String]
    /// Reads raw dependency dictionary representation:
    /// * key is a filename of the dependency (or some "magicals", like Xcode's 'dependencies' or 'skipForSha')
    /// * value is an array of dependencies related with 'key' file
    func readFilesAndDependencies() throws -> [String: [String]]
}

/// Parser for a single .d file
public class FileDependenciesReader: DependenciesReader {
    private let file: URL
    private let fileManager: FileManager

    public init(_ file: URL, accessor: FileManager) {
        self.file = file
        fileManager = accessor
    }

    public func findDependencies() throws -> [String] {
        let yaml = try readRaw()

        struct ParseState {
            var buffer: String = ""
            var prevChar: Character?
            var result: [String] = []
            func with(buffer: String? = nil, prevChar: Character? = nil, result: [String]? = nil) -> ParseState {
                var new = self
                new.buffer = buffer ?? new.buffer
                new.prevChar = prevChar ?? new.prevChar
                new.result = result ?? new.result
                return new
            }
        }

        let dependencies = yaml.reduce(Set<String>()) { prev, arg1 -> Set<String> in
            let (key, value) = arg1
            switch key {
            case "dependencies":
                // 'clang' output formatting
                return Set(splitDependencyFileList(value))
            case let s where s.hasSuffix(".o") || s.hasSuffix(".bc"):
                // 'swiftc' output formatting
                // take dependencies from any .o or .bc file.
                // Note: For WMO, all .{o|bc} files have the same dependencies
                return Set(splitDependencyFileList(value))
            default:
                return prev
            }
        }
        return Array(dependencies)
    }

    public func findInputs() throws -> [String] {
        exit(1, "TODO: implement")
    }

    public func readFilesAndDependencies() throws -> [String: [String]] {
        let yaml = try readRaw()
        // files are space delimited
        return yaml.mapValues { $0.components(separatedBy: .whitespaces) }
    }

    private func readRaw() throws -> [String: String] {
        guard let fileData = fileManager.contents(atPath: file.path) else {
            throw DependenciesReaderError.readingError
        }
        guard let fileString = String(data: fileData, encoding: .utf8) else {
            throw DependenciesReaderError.invalidFile
        }
        // .d matches the .yaml format
        guard let yaml = try Yams.load(yaml: fileString) as? [String: String] else {
            throw DependenciesReaderError.invalidFile
        }
        return yaml
    }

    /// Splits space or new line separated files into a set of files
    /// It supports escaping whitespace charaters, prefixed with "\\"
    /// - Parameter string: string of whitespace charaters separated file paths
    /// - Returns: Array of all file paths
    private func splitDependencyFileList(_ string: String) -> [String] {
        struct ParseState {
            var buffer: String = ""
            var prevChar: Character?
            var result: [String] = []
            func with(buffer: String? = nil, prevChar: Character? = nil, result: [String]? = nil) -> ParseState {
                var new = self
                new.buffer = buffer ?? new.buffer
                new.prevChar = prevChar ?? new.prevChar
                new.result = result ?? new.result
                return new
            }
        }
        let parseResult = string.reduce(ParseState()) { total, char in
            switch char {
            case "\n" where total.prevChar == "\\":
                return total
            case " " where total.buffer.isEmpty:
                return total
            case " " where total.prevChar == "\\":
                return total.with(buffer: "\(total.buffer) ")
            case " ":
                return total.with(buffer: "", prevChar: nil, result: total.result + [total.buffer])
            case "\\":
                return total.with(prevChar: "\\")
            default:
                return total.with(buffer: "\(total.buffer)\(char)", prevChar: char, result: total.result)
            }
        }
        if !parseResult.buffer.isEmpty {
            return parseResult.result + [parseResult.buffer]
        }
        return parseResult.result
    }
}
