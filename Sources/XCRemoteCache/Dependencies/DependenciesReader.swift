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

        let dependencies = yaml.reduce(Set<String>()) { prev, arg1 -> Set<String> in
            let (key, value) = arg1
            switch key {
            case "dependencies":
                // 'clang' output formatting
                return Set(parseDependencyFileList(value))
            case let s where s.hasSuffix(".o") || s.hasSuffix(".bc"):
                // 'swiftc' output formatting
                // take dependencies from any .o or .bc file
                // Note: For WMO, all .{o|bc} files have the same dependencies
                return Set(parseDependencyFileList(value))
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

    func readRaw() throws -> [String: String] {
        let fileData = try getFileData()
        let fileString = try getFileStringFromData(fileData: fileData)
        let yaml = try getYaml(fileString: fileString)
        return yaml
    }

    func getFileData() throws -> Data {
        guard let fileData = fileManager.contents(atPath: file.path) else {
            throw DependenciesReaderError.readingError
        }
        return fileData
    }

    func getFileStringFromData(fileData: Data) throws -> String {
        guard let fileString = String(data: fileData, encoding: .utf8) else {
            throw DependenciesReaderError.invalidFile
        }
        return fileString
    }

    func getYaml(fileString: String) throws -> [String: String] {
        guard let yaml = try Yams.load(yaml: fileString) as? [String: String] else {
            throw DependenciesReaderError.invalidFile
        }
        return yaml
    }

    /// Parses the String to get the list of files.
    /// It iterates over the String using its UTF8View since it is more performant (String type operates in a higher abstraction level and includes features that impact the performance)
    /// It supports escaping whitespace charaters, prefixed with "\\"
    /// - Parameter string: string of whitespace charaters separated file paths
    /// - Returns: Array of all file paths
    func parseDependencyFileList(_ string: String) -> [String] {
        var result: [String] = []
        var prevChar: UTF8.CodeUnit?

        // These index are used to move over the UTF8View of the string.
        // The goal is to optimize the memory used, since UTF8View uses the same memory as the original String without copying it.
        var startIndex = string.utf8.startIndex
        var endIndex = startIndex

        // This buffer is only used to save the part of the path that has been already parsed when finding a backslash
        var buffer: String = ""

        for c in string.utf8 {
          switch c {
          case UTF8.CodeUnit(ascii: "\n") where prevChar == UTF8.CodeUnit(ascii: "\\"):
              startIndex = string.utf8.index(after: startIndex)
              endIndex = startIndex
          case UTF8.CodeUnit(ascii: " ") where startIndex == endIndex && buffer.isEmpty:
              startIndex = string.utf8.index(after: startIndex)
              endIndex = startIndex
          case UTF8.CodeUnit(ascii: " ") where prevChar != UTF8.CodeUnit(ascii: "\\"):
              // If a space is found and it is not escaped, then that's the end of the file path
              buffer += String(Substring(string.utf8[startIndex ..< endIndex]))
              result.append(buffer)
              buffer = ""
              prevChar = nil
              startIndex = string.utf8.index(after: endIndex)
              endIndex = startIndex
          case UTF8.CodeUnit(ascii: "\\"):
              // If a backslash is found it is not included in the file path
              // The current parsed range of the UTF8View is saved in the buffer as a String
              buffer += String(Substring(string.utf8[startIndex ..< endIndex]))
              // The backslash is assigned as the previous char
              prevChar = c
              // The indexes are moved to the next char so we continue parsing the String
              startIndex = string.utf8.index(after: endIndex)
              endIndex = startIndex
          default:
              // As long as it is possible the indexes are used to track the range of the string that will be included in the file path (until it ends or until a backslash is found)
              endIndex = string.utf8.index(after: endIndex)
              // The char is assigned as the previous char
              prevChar = c
          }
        }

        if startIndex != endIndex {
            buffer += String(Substring(string.utf8[startIndex ..< endIndex]))
            result.append(buffer)
        }

        return result
    }


    /// Splits space or new line separated files into a set of files
    /// It supports escaping whitespace charaters, prefixed with "\\"
    /// - Parameter string: string of whitespace charaters separated file paths
    /// - Returns: Array of all file paths
    @available(*, deprecated, message: "Deprecated in favor of parseDependencyFileList which is more performant")
    func splitDependencyFileList(_ string: String) -> [String] {
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
