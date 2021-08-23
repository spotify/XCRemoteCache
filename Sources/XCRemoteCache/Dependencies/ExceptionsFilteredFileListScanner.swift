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

/// Verifies if the filename should be always disallowed/allowed. If a filename does not match with allowed/disallowed
/// entries, the decision is handled by the underlying `scanner`
/// Note: disallowed filenames have higher priorities than allowed ones
class ExceptionsFilteredFileListScanner: FileListScanner {
    private let listScanner: FileListScanner
    private let allowedFilenames: [String]
    private let disallowedFilenames: [String]

    /// Default initializer that specifies disallowed and allowed filenames (including an extention)
    /// Valid filenames: ['file.swift', 'file.m']
    /// Invalid filenames: ['somePath/file.swift', '/absolutePath/file.m']
    ///
    /// - Parameters:
    ///   - allowedFilenames: a list of filenames which should always be allowed
    ///   - disallowedFilenames: a list of filenames which should always be disallowed
    ///   - scanner: underlying scanner that decides if non of allowed/disallowed pattern matches
    init(allowedFilenames: [String], disallowedFilenames: [String], scanner: FileListScanner) {
        self.allowedFilenames = allowedFilenames
        self.disallowedFilenames = disallowedFilenames
        listScanner = scanner
    }

    func contains(_ url: URL) throws -> Bool {
        let filename = url.lastPathComponent
        if disallowedFilenames.contains(filename) {
            return false
        }
        if allowedFilenames.contains(filename) {
            return true
        }
        return try listScanner.contains(url)
    }
}
