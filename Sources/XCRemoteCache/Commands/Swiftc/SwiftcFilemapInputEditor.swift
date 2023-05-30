// Copyright (c) 2021 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import Foundation
import Yams

/// Errors with reading swiftc inputs
enum SwiftcInputReaderError: Error {
    case readingFailed
    case invalidFormat
    case invalidYamlFormat
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
    // might be nil for the swift-frontend '-c' invocation
    let swiftDependencies: URL?
}

public struct SwiftFileCompilationInfo: Encodable, Hashable {
    let file: URL
    // not present for WMO builds
    let dependencies: URL?
    // not present for 'indexbuild' builds
    let object: URL?
    // not present for WMO builds
    let swiftDependencies: URL?
}

class SwiftcFilemapInputEditor: SwiftcInputReader, SwiftcInputWriter {

    enum Format {
        case json
        case yaml
    }

    private let file: URL
    private let fileFormat: Format
    private let fileManager: FileManager

    init(_ file: URL, fileFormat: Format, fileManager: FileManager) {
        self.file = file
        self.fileFormat = fileFormat
        self.fileManager = fileManager
    }

    func read() throws -> SwiftCompilationInfo {
        guard let content = fileManager.contents(atPath: file.path) else {
            throw SwiftcInputReaderError.readingFailed
        }
        guard let representation = try decodeFile(content: content) else {
            throw SwiftcInputReaderError.invalidFormat
        }
        return try SwiftCompilationInfo(from: representation)
    }

    func write(_ info: SwiftCompilationInfo) throws {
        let data = try JSONSerialization.data(withJSONObject: info.dump(), options: [.prettyPrinted])
        fileManager.createFile(atPath: file.path, contents: data, attributes: nil)
    }

    private func decodeFile(content: Data) throws -> [String: Any]? {
        switch fileFormat {
        case .json:
            return try JSONSerialization.jsonObject(with: content, options: []) as? [String: Any]
        case .yaml:
            return try Yams.load(yaml: String(data: content, encoding: .utf8)!) as? [String: Any]
        }
    }
}

extension SwiftCompilationInfo {
    init(from object: [String: Any]) throws {
        info = try SwiftModuleCompilationInfo(from: object["", default: [:]])
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
        swiftDependencies = dict.readURL(key: "swift-dependencies")
        dependencies = dict.readURL(key: "dependencies")
    }

    func dump() -> [String: String] {
        return [
            "dependencies": dependencies?.path,
            "swift-dependencies": swiftDependencies?.path,
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
        object = dict.readURL(key: "object")
        swiftDependencies = dict.readURL(key: "swift-dependencies")
    }

    func dump() -> [String: String] {
        return [
            "dependencies": dependencies?.path,
            "object": object?.path,
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
