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

/// DirAccessor composer that uses custom file accessor and dir scanner
class DirAccessorComposer: DirAccessor {
    private let fileAccessor: FileAccessor
    private let dirScanner: DirScanner

    init(fileAccessor: FileAccessor, dirScanner: DirScanner) {
        self.fileAccessor = fileAccessor
        self.dirScanner = dirScanner
    }

    func write(toPath: String, contents: Data?) throws {
        try fileAccessor.write(toPath: toPath, contents: contents)
    }

    func removeItem(atPath path: String) throws {
        try fileAccessor.removeItem(atPath: path)
    }

    func contents(atPath path: String) throws -> Data? {
        try fileAccessor.contents(atPath: path)
    }

    func fileExists(atPath path: String) -> Bool {
        fileAccessor.fileExists(atPath: path)
    }

    func itemType(atPath path: String) throws -> ItemType {
        try dirScanner.itemType(atPath: path)
    }

    func items(at dir: URL) throws -> [URL] {
        try dirScanner.items(at: dir)
    }

    func recursiveItems(at dir: URL) throws -> [URL] {
        try dirScanner.recursiveItems(at: dir)
    }
}
