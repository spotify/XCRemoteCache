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

enum MetaReaderError: Error {
    /// Missing file that should contain the meta
    case missingFile(URL)
}

/// Parses and provides `MainArtifactMeta`. Supports reading from a disk or directly from provided data representation
protocol MetaReader {
    /// Reads from a local disk location
    /// - Parameter localFile: location of the file to parse
    func read(localFile: URL) throws -> MainArtifactMeta
    /// Reads from a data representation
    /// - Parameter data: meta representation
    func read(data: Data) throws -> MainArtifactMeta
}

/// Parses `MainArtifactMeta` from a JSON representation
class JsonMetaReader: MetaReader {
    private let decoder = JSONDecoder()
    private let fileAccessor: FileAccessor

    init(fileAccessor: FileAccessor) {
        self.fileAccessor = fileAccessor
    }

    func read(localFile: URL) throws -> MainArtifactMeta {
        guard let data = try fileAccessor.contents(atPath: localFile.path) else {
            throw MetaReaderError.missingFile(localFile)
        }
        return try read(data: data)
    }

    func read(data: Data) throws -> MainArtifactMeta {
        return try decoder.decode(MainArtifactMeta.self, from: data)
    }
}
