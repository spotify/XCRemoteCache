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

import XCTest

/// Helper class that prepares an empty, source-file exclusive directory
/// Warning: Derived classes should call `try super.tearDownWithError()` if override `tearDownWithError` function
class FileXCTestCase: XCTestCase {
    private(set) var workingDirectory: URL?
    let fileManager = FileManager.default


    @discardableResult
    func prepareTempDir(_ dirKey: String = #file) throws -> URL {
        if let dir = workingDirectory {
            return dir
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(dirKey).resolvingSymlinksInPath()
        // Make sure the potentially dirty dir is removed
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        workingDirectory = url
        return url
    }

    private func cleanupFiles() throws {
        guard let dir = workingDirectory else {
            return
        }
        if fileManager.fileExists(atPath: dir.path) {
            try fileManager.removeItem(at: dir)
        }
    }

    override func tearDownWithError() throws {
        try cleanupFiles()
        try super.tearDownWithError()
    }
}
