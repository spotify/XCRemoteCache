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

/// Testing helper functions that manage files and dirs on a disk
extension FileManager {
    @discardableResult
    func spt_createEmptyFile(_ url: URL) throws -> URL {
        try spt_createFile(url, content: nil)
    }

    @discardableResult
    func spt_createFile(_ url: URL, content: String?) throws -> URL {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
        try spt_ensureDir(url.deletingLastPathComponent())
        let contents = content.flatMap { $0.data(using: .utf8) }
        createFile(atPath: url.path, contents: contents, attributes: nil)
        return url
    }

    func spt_ensureDir(_ url: URL) throws {
        if fileExists(atPath: url.path) {
            return
        }
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    @discardableResult
    func spt_createEmptyDir(_ url: URL) throws -> URL {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }

    func spt_allFilesRecusively(_ url: URL) throws -> [URL] {
        guard fileExists(atPath: url.path) else {
            throw "No directory \(url)"
        }
        let allURLs = try contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        return try allURLs.reduce([URL]()) { urls, url in
            var isDir: ObjCBool = false
            fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
                return try urls + spt_allFilesRecusively(url)
            }
            return urls + [url.resolvingSymlinksInPath()]
        }
    }
}
