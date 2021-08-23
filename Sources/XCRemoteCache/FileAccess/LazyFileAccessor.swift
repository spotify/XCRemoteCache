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

/// Writes to a file only if the existing content of a file doesn't exist or its content doesn't match
class LazyFileAccessor: FileAccessor {
    private let accessor: FileAccessor

    init(fileAccessor: FileAccessor) {
        accessor = fileAccessor
    }

    func write(toPath path: String, contents: Data?) throws {
        guard let fileContent = try accessor.contents(atPath: path) else {
            try accessor.write(toPath: path, contents: contents)
            return
        }
        guard fileContent != contents else {
            // Files content match - no need to write it to a file
            return
        }
        try accessor.write(toPath: path, contents: contents)
    }

    func removeItem(atPath path: String) throws {
        try accessor.removeItem(atPath: path)
    }

    func contents(atPath path: String) throws -> Data? {
        return try accessor.contents(atPath: path)
    }

    func fileExists(atPath path: String) -> Bool {
        return accessor.fileExists(atPath: path)
    }
}
