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

@testable import XCRemoteCache
import XCTest

class DirAccessorFake: DirAccessor {
    private var memory: [URL: Data] = [:]

    func itemType(atPath path: String) throws -> ItemType {
        if fileExists(atPath: path) {
            return .file
        }
        // iterate all files to see it is a dir
        let isDir = memory.first { fileURL, _ in
            fileURL.path.hasPrefix(path)
        }
        if isDir != nil {
            return .dir
        }
        return .nonExisting
    }

    func items(at dir: URL) throws -> [URL] {
        memory.compactMap { url, _ in
            // compare paths to ignore dir or url's "isDir"
            if url.deletingLastPathComponent().path == dir.path {
                return url
            }
            return nil
        }
    }

    func recursiveItems(at dir: URL) throws -> [URL] {
        memory.compactMap { url, _ in
            // compare paths to ignore dir or url's "isDir"
            if url.deletingLastPathComponent().path.starts(with: dir.path) {
                return url
            }
            return nil
        }
    }

    func contents(atPath path: String) throws -> Data? {
        memory[URL(fileURLWithPath: path)]
    }

    func fileExists(atPath path: String) -> Bool {
        memory[URL(fileURLWithPath: path)] != nil
    }

    func write(toPath: String, contents: Data?) throws {
        memory[URL(fileURLWithPath: toPath)] = contents
    }

    func removeItem(atPath path: String) throws {
        memory[URL(fileURLWithPath: path)] = nil
    }
}
