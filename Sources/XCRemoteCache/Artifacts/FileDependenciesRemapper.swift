// Copyright (c) 2022 Spotify AB.
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


enum FileDependenciesRemapperError: Error {
    /// Thrown when the file to remap is invalid (e.g. doesn't exist or has unexpected format)
    case invalidRemappingFile(URL)
}

/// Replaces paths in a file content between generic (placeholders-based)
/// and local formats
protocol FileDependenciesRemapper {
    /// Replaces all generic paths (with placeholders) to a local, machine
    /// specific absolute paths
    /// - Parameter url: location of a file that should be remapped in-place
    func remap(fromGeneric url: URL) throws
    /// Replaces all local, machine specific absolute paths to
    /// generic ones
    /// - Parameter url: location of a file that should be remapped in-place
    func remap(fromLocal url: URL) throws
}

/// Remaps absolute paths in a text files stored on a disk
/// Note: That class should not be used in bynary files, only text-based
class TextFileDependenciesRemapper: FileDependenciesRemapper {
    private static let linesSeparator = "\n"
    private let remapper: DependenciesRemapper
    private let fileAccessor: FileAccessor

    init(remapper: DependenciesRemapper, fileAccessor: FileAccessor) {
        self.remapper = remapper
        self.fileAccessor = fileAccessor
    }

    private func readFileLines(_ url: URL) throws -> [String] {
        guard let content = try fileAccessor.contents(atPath: url.path) else {
            // the file is empty
            return []
        }
        guard let contentString = String(data: content, encoding: .utf8) else {
            throw FileDependenciesRemapperError.invalidRemappingFile(url)
        }
        var lines: [String] = []
        contentString.enumerateLines { line, stop in
            lines.append(line)
        }
        return lines
    }

    private func storeFileLines(lines: [String], url: URL) throws {
        let contentString = lines.joined(separator: "\n")
        let contentData = contentString.data(using: String.Encoding.utf8)
        try fileAccessor.write(toPath: url.path, contents: contentData)
    }

    func remap(fromGeneric url: URL) throws {
        let contentLines = try readFileLines(url)
        let remappedContent = try remapper.replace(genericPaths: contentLines)
        try storeFileLines(lines: remappedContent, url: url)
    }

    func remap(fromLocal url: URL) throws {
        let contentLines = try readFileLines(url)
        let remappedContent = try remapper.replace(localPaths: contentLines)
        try storeFileLines(lines: remappedContent, url: url)
    }
}
