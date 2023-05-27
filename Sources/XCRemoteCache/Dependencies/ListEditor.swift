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

enum ListReaderError: Error {
    /// The file to read a list doesn't exist or is not readable
    case cannotReadFile
    /// The file content is invalid (e.g. cannot be represented as a String)
    case invalidContent
}

/// Reads a list of files
protocol ListReader {
    /// Fetches all dependencies
    /// - Throws: `ListReaderError`
    func listFilesURLs() throws -> [URL]
    /// Returns true if the reader is able to read a list of files
    func canRead() -> Bool
}

protocol ListWriter {
    /// Writes a new list of files
    /// - Parameter list: files to save in a file list
    func writerListFilesURLs(_ list: [URL]) throws
}

/// Reads&Writes files that list files using one-file-per-line format
class FileListEditor: ListReader, ListWriter {
    private let file: URL
    private let fileManager: FileManager
    /// cached list of files
    private var cachedFiles: [URL]?

    init(_ file: URL, fileManager: FileManager) {
        self.file = file
        self.fileManager = fileManager
    }

    func listFilesURLs() throws -> [URL] {
        if let files = cachedFiles {
            return files
        }
        guard let content = fileManager.contents(atPath: file.path) else {
            throw ListReaderError.cannotReadFile
        }
        guard let fileStrings = String(data: content, encoding: .utf8)?.split(separator: "\n") else {
            throw ListReaderError.invalidContent
        }
        let files = fileStrings.map(escapeFilename).map(URL.init(fileURLWithPath:))
        cachedFiles = files
        return files
    }

    func canRead() -> Bool {
        return fileManager.fileExists(atPath: file.path)
    }

    private func escapeFilename(_ path: String.SubSequence) -> String {
        String(path).replacingOccurrences(of: "\\ ", with: " ")
    }

    private func unescapeFilename(_ path: String) -> String {
        path.replacingOccurrences(of: " ", with: "\\ ")
    }

    func writerListFilesURLs(_ list: [URL]) throws {
        let data = list.map(\.path).map(unescapeFilename).joined(separator: "\n").data(using: .utf8)!
        fileManager.createFile(atPath: file.path, contents: data, attributes: nil)
    }
}
