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

/// Reads and aggregates all compilation dependencies from a single directory
class TargetDependenciesReader: DependenciesReader {
    private let directory: URL
    private let dirScanner: DirScanner
    private let fileDependeciesReaderFactory: (URL) -> DependenciesReader

    public init(
        _ directory: URL,
        fileDependeciesReaderFactory: @escaping (URL) -> DependenciesReader,
        dirScanner: DirScanner
    ) {
        self.directory = directory
        self.dirScanner = dirScanner
        self.fileDependeciesReaderFactory = fileDependeciesReaderFactory
    }

    // Optimized way of finding dependencies only for files that have corresponding .o file on a disk
    public func findDependencies() throws -> [String] {
        // Not calling `readFilesAndDependencies` as it may unnecessary call expensive `findDependencies()` for
        // files that eventually will not be considered
        let allURLs = try dirScanner.items(at: directory)
        let mergedDependencies = try allURLs.reduce(Set<String>()) { (prev: Set<String>, file) in
            // include only these .d files that either have corresponding .o file (incremental) or end
            // with '-master' (whole-module)
            // Otherwise .d is probably just a leftover from previous builds
            let correspondingOutputURL = file.deletingPathExtension().appendingPathExtension("o")
            let isDependencyFile = file.pathExtension == "d"
            let isWholeModuleDependencyFile = file.deletingPathExtension().lastPathComponent.hasSuffix("-master")
            // TODO: migrate to simple `lazy var` once compiling with Swift 5.4 (Xcode 12.5+)
            let correspondingFileExists = { try self.dirScanner.itemType(atPath: correspondingOutputURL.path) == .file }
            guard try isDependencyFile && (isWholeModuleDependencyFile || correspondingFileExists()) else {
                return prev
            }

            return try prev.union(fileDependeciesReaderFactory(file).findDependencies())
        }
        return Array(mergedDependencies).sorted()
    }

    public func findInputs() throws -> [String] {
        fatalError("TODO: implement")
    }

    public func readFilesAndDependencies() throws -> [String: [String]] {
        let allURLs = try dirScanner.items(at: directory)
        return try allURLs.reduce([String: [String]]()) { prev, file in
            var new = prev
            new[file.path] = try fileDependeciesReaderFactory(file).findDependencies()
            return new
        }
    }
}
