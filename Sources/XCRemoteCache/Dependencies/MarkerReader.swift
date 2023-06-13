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

/// Reads a list of files from a marker file
class FileMarkerReader: ListReader {
    private let file: URL
    private let fileReader: FileReader
    private var cachedFiles: [URL]?

    init(_ file: URL, fileManager: FileReader) {
        self.file = file
        self.fileReader = fileManager
    }

    func listFilesURLs() throws -> [URL] {
        if let cachedResponse = cachedFiles {
            return cachedResponse
        }
        // Skipping first marker line `dependencies: //`
        let fileLines = try String(contentsOf: file).split(separator: "\n").dropFirst()
        let files = fileLines.map { line in
            line.replacingOccurrences(of: FileMarkerWriter.delimiter, with: "")
        }
        let filesURLs = files.map(URL.init(fileURLWithPath:))
        cachedFiles = filesURLs
        return filesURLs
    }

    func canRead() -> Bool {
        return fileReader.fileExists(atPath: file.path)
    }
}
