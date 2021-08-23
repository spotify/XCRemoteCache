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

/// Manage marker file entries
protocol MarkerWriter {
    /// Saves all dependencies
    func enable(dependencies: [URL]) throws
    /// Disables mode marker
    func disable() throws
}

/// Saves a marker using a format matching .d one
class FileMarkerWriter: MarkerWriter {
    static let delimiter = " \\"
    private let filePath: String
    private let fileAccessor: FileAccessor

    init(_ file: URL, fileAccessor: FileAccessor) {
        filePath = file.path
        self.fileAccessor = fileAccessor
    }

    func enable(dependencies: [URL]) throws {
        let lines = ["dependencies: "] + dependencies.map { $0.path }
        let fileContent = lines.joined(separator: "\(Self.delimiter)\n")
        try fileAccessor.write(toPath: filePath, contents: fileContent.data(using: .utf8))
    }

    func disable() throws {
        if fileAccessor.fileExists(atPath: filePath) {
            try fileAccessor.removeItem(atPath: filePath)
        }
    }
}

/// Marker Writer that does nothing
class NoopMarkerWriter: MarkerWriter {
    init(_ file: URL, fileManager: FileManager) {}

    func enable(dependencies: [URL]) throws {}

    func disable() throws {}
}
