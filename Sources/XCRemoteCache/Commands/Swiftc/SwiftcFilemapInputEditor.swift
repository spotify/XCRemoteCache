import Foundation

/// Errors with reading swiftc inputs
enum SwiftcInputReaderError: Error {
    case readingFailed
    case invalidFormat
    case missingField(String)
}

/// Reads SwiftC filemap that specifies all input and output files
/// for the compilation
protocol SwiftcInputReader {
    func read() throws -> SwiftCompilationInfo
}

/// Modifies compilation info
protocol SwiftcInputWriter {
    func write(_ info: SwiftCompilationInfo) throws
}

struct SwiftCompilationInfo: Encodable, Equatable {
    var info: SwiftModuleCompilationInfo
    var files: [SwiftFileCompilationInfo]
}

struct SwiftModuleCompilationInfo: Encodable, Equatable {
    // not present for incremental builds
    let dependencies: URL?
    let swiftDependencies: URL
}

struct SwiftFileCompilationInfo: Encodable, Equatable {
    let file: URL
    // not present for WMO builds
    let dependencies: URL?
    let object: URL
    // not present for WMO builds
    let swiftDependencies: URL?
}

class SwiftcFilemapInputEditor: SwiftcInputReader, SwiftcInputWriter {

    private let file: URL
    private let fileManager: FileManager

    init(_ file: URL, fileManager: FileManager) {
        self.file = file
        self.fileManager = fileManager
    }

    func read() throws -> SwiftCompilationInfo {
        guard let content = fileManager.contents(atPath: file.path) else {
            throw SwiftcInputReaderError.readingFailed
        }
        guard let representation = try JSONSerialization.jsonObject(with: content, options: []) as? [String: Any] else {
            throw SwiftcInputReaderError.invalidFormat
        }
        return try SwiftCompilationInfo(from: representation)
    }

    func write(_ info: SwiftCompilationInfo) throws {
        let data = try JSONSerialization.data(withJSONObject: info.dump(), options: [.prettyPrinted])
        fileManager.createFile(atPath: file.path, contents: data, attributes: nil)
    }
}

extension SwiftCompilationInfo {
    init(from object: [String: Any]) throws {
        info = try SwiftModuleCompilationInfo(from: object[""])
        files = try object.reduce([]) { prev, new in
            let (key, value) = new
            if key.isEmpty {
                return prev
            }
            let fileInfo = try SwiftFileCompilationInfo(name: key, from: value)
            return prev + [fileInfo]
        }
    }

    func dump() -> [String: Any] {
        return files.reduce(["": info.dump()]) { prev, info in
            var result = prev
            result[info.file.path] = info.dump()
            return result
        }
    }
}

extension SwiftModuleCompilationInfo {
    init(from object: Any?) throws {
        guard let dict = object as? [String: String] else {
            throw SwiftcInputReaderError.invalidFormat
        }
        swiftDependencies = try dict.readURL(key: "swift-dependencies")
        dependencies = dict.readURL(key: "dependencies")
    }

    func dump() -> [String: String] {
        return [
            "dependencies": dependencies?.path,
            "swift-dependencies": swiftDependencies.path,
        ].compactMapValues { $0 }
    }
}

extension SwiftFileCompilationInfo {
    init(name: String, from inputObject: Any) throws {
        guard let dict = inputObject as? [String: String] else {
            throw SwiftcInputReaderError.invalidFormat
        }
        file = URL(fileURLWithPath: name)
        dependencies = dict.readURL(key: "dependencies")
        object = try dict.readURL(key: "object")
        swiftDependencies = dict.readURL(key: "swift-dependencies")
    }

    func dump() -> [String: String] {
        return [
            "dependencies": dependencies?.path,
            "object": object.path,
            "swift-dependencies": swiftDependencies?.path,
        ].compactMapValues { $0 }
    }
}

private extension Dictionary where Key == String, Value == String {
    func readURL(key: String) throws -> URL {
        guard let value = self[key].map(URL.init(fileURLWithPath:)) else {
            throw SwiftcInputReaderError.missingField(key)
        }
        return value
    }

    func readURL(key: String) -> URL? {
        return self[key].map(URL.init(fileURLWithPath:))
    }
}
