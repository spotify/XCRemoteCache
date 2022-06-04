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

class FileManagerDirScannerTests: FileXCTestCase {
    private var dirScanner: DirScanner!

    override func setUpWithError() throws {
        try super.setUpWithError()
        _ = try prepareTempDir()

        dirScanner = FileManager.default
    }

    func testRecognizesNonExistingItem() {
        let file = workingDirectory!.appendingPathComponent("non.existing")

        try XCTAssertEqual(fileManager.itemType(atPath: file.path), .nonExisting)
    }

    func testRecognizesFileItem() throws {
        let file = workingDirectory!.appendingPathComponent("existing.file")
        try fileManager.spt_createEmptyFile(file)

        try XCTAssertEqual(fileManager.itemType(atPath: file.path), .file)
    }

    func testRecognizesDirItem() throws {
        let dir = workingDirectory!.appendingPathComponent("dir")
        try fileManager.spt_createEmptyDir(dir)

        try XCTAssertEqual(fileManager.itemType(atPath: dir.path), .dir)
    }

    func testFindsFilesInAFlatDir() throws {
        // workingDirectory may contain symbolic links in a path
        let dir = workingDirectory!.resolvingSymlinksInPath()
        let subDir = dir.appendingPathComponent("dir", isDirectory: true)
        let file1 = dir.appendingPathComponent("file1")
        let file2 = subDir.appendingPathComponent("file2")
        try fileManager.spt_createEmptyFile(file1)
        try fileManager.spt_createEmptyFile(file2)

        let items = try dirScanner.items(at: dir)

        // returned items may contain symbolic links in a path
        let resolvedItems = items.map { $0.resolvingSymlinksInPath() }
        XCTAssertEqual(Set(resolvedItems), Set([subDir, file1]))
    }

    func testFailsToFindItemsNonExistingDir() throws {
        let dir = workingDirectory!.appendingPathComponent("dir")

        try XCTAssertThrowsError(dirScanner.items(at: dir))
    }

    func testFindsAllFilesRecursively() throws {
        let dir = workingDirectory!.appendingPathComponent("dir")
        let nestedDir = dir.appendingPathComponent("nested")
        let nestedFile = nestedDir.appendingPathComponent("file")
        try fileManager.spt_createEmptyFile(nestedFile)

        let allFiles = try dirScanner.recursiveItems(at: dir)

        let allFilesResolve = allFiles.map({$0.resolvingSymlinksInPath()})
        XCTAssertEqual(allFilesResolve, [nestedFile])
    }
}
