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

/// Type of an item placed in a directory
enum ItemType {
    case file
    case dir
    case nonExisting
}

protocol DirScanner {
    /// Returns a type an item
    /// - Parameter atPath: path of a file
    func itemType(atPath path: String) throws -> ItemType

    /// Returns all items in a directory (shallow search)
    /// - Parameter at: url of an existing directory to search
    /// - Throws: an error if dir doesn't exist or I/O error
    func items(at dir: URL) throws -> [URL]

    /// Returns all items in a directory (recursive search)
    /// - Parameter at: url of an existing directory to search
    /// - Throws: an error if dir doesn't exist or I/O error
    func recursiveItems(at dir: URL) throws -> [URL]
}

typealias DirAccessor = FileAccessor & DirScanner

extension FileManager: DirScanner {
    func itemType(atPath path: String) throws -> ItemType {
        var isDir: ObjCBool = false
        guard fileExists(atPath: path, isDirectory: &isDir) else {
            // dir doesn't exist
            return .nonExisting
        }
        return isDir.boolValue ? .dir : .file
    }

    func items(at dir: URL) throws -> [URL] {
        // FileManager is not capable of listing files if the URL includes symlinks
        let resolvedDir = dir.resolvingSymlinksInPath()
        return try contentsOfDirectory(at: resolvedDir, includingPropertiesForKeys: nil, options: [])
    }

    func recursiveItems(at dir: URL) throws -> [URL] {
        // Iterating DFS
        var queue: [URL] = [dir]
        var results: [URL] = []
        while let item = queue.popLast() {
            if try itemType(atPath: item.path) == .dir {
                try queue.append(contentsOf: items(at: item))
            } else {
                results.append(item)
            }
        }
        return results
    }
}
