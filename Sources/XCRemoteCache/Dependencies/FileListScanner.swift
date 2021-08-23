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

protocol FileListScanner {
    /// Returns true if the url is present in the file list
    func contains(_ url: URL) throws -> Bool
}

/// Finds file on a list of files provied by ListReader
class FileListScannerImpl: FileListScanner {
    private let fileList: ListReader
    private let caseSensitive: Bool

    init(_ fileList: ListReader, caseSensitive: Bool) {
        self.fileList = fileList
        self.caseSensitive = caseSensitive
    }

    func contains(_ url: URL) throws -> Bool {
        if caseSensitive {
            return try fileList.listFilesURLs().contains(url)
        }
        let lowerCasePath = url.path.lowercased()
        return try fileList.listFilesURLs().lazy.contains { element in
            element.path.lowercased() == lowerCasePath
        }
    }
}
