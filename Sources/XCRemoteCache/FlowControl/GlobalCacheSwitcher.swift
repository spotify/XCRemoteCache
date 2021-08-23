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

/// Protocol that controls global (cross-targets) remote cache status
protocol GlobalCacheSwitcher {
    /// Enables remote cache for a specific commit sha
    /// - Parameter sha: sha of a commit
    func enable(sha: String) throws
    /// Fully disables remote cache
    func disable() throws
}

/// Controls remote cache status using an on-disk file
class FileGlobalCacheSwitcher: GlobalCacheSwitcher {
    private let filePath: String
    private let fileAccessor: FileAccessor

    init(_ file: URL, fileAccessor: FileAccessor) {
        filePath = file.path
        self.fileAccessor = fileAccessor
    }

    func enable(sha: String) throws {
        let shaData = sha.data(using: .utf8)!
        try fileAccessor.write(toPath: filePath, contents: shaData)
    }

    /// Disables remote cache by saving an empty file
    /// Note: This section doesn't need to acquire a lock to write. Non-empty content is set only in the
    /// `xcprepare`, that is always run exclusively. All other commands that run in parallel can only empty that file
    func disable() throws {
        if fileAccessor.fileExists(atPath: filePath) {
            try fileAccessor.write(toPath: filePath, contents: Data())
        }
    }
}
