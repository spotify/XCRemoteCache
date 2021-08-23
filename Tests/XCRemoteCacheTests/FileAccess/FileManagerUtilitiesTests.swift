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

class FileManagerUtilitiesTests: FileXCTestCase {

    private let manager = FileManager.default

    func testForceLinkItemCreatesParentDir() throws {
        let sampleFile = try prepareTempDir().appendingPathComponent("file.txt")
        let linkDestination = try prepareTempDir().appendingPathComponent("dir").appendingPathComponent("file.txt")
        try fileManager.spt_createEmptyFile(sampleFile)

        try manager.spt_forceLinkItem(at: sampleFile, to: linkDestination)

        XCTAssertTrue(fileManager.fileExists(atPath: linkDestination.path))
    }

    func testDeletingFile() throws {
        let sampleFile = try prepareTempDir().appendingPathComponent("file.txt")
        try fileManager.spt_createEmptyFile(sampleFile)

        try manager.spt_deleteItem(at: sampleFile)

        XCTAssertFalse(fileManager.fileExists(atPath: sampleFile.path))
    }

    func testDeletingNonExistingFileDoesNotThrow() throws {
        let sampleFileURL = try prepareTempDir().appendingPathComponent("file.txt")

        XCTAssertNoThrow(try manager.spt_deleteItem(at: sampleFileURL))
    }

    func testDeletingDir() throws {
        let sampleDir = try prepareTempDir().appendingPathComponent("dir")
        try fileManager.spt_createEmptyDir(sampleDir)

        try manager.spt_deleteItem(at: sampleDir)

        XCTAssertFalse(fileManager.fileExists(atPath: sampleDir.path))
    }

    func testDeletingNonExistingDirDoesNotThrow() throws {
        let sampleDir = try prepareTempDir().appendingPathComponent("dir")

        XCTAssertNoThrow(try manager.spt_deleteItem(at: sampleDir))
    }

    func testListsItemsWithSymlinkInPath() throws {
        let sampleDir = try prepareTempDir()
        let directory = sampleDir.appendingPathComponent("directory")
        let fileInDirectory = directory.appendingPathComponent("file.txt")
        let locationWithSymlink = sampleDir.appendingPathComponent("symlink")
        try fileManager.spt_createEmptyFile(fileInDirectory)
        try fileManager.createSymbolicLink(at: locationWithSymlink, withDestinationURL: directory)

        let allFiles = try fileManager.items(at: locationWithSymlink)

        let allFilesSymlinkResolved = allFiles.map { $0.resolvingSymlinksInPath() }
        let expectedFileSymlinkResolved = fileInDirectory.resolvingSymlinksInPath()
        XCTAssertEqual(allFilesSymlinkResolved, [expectedFileSymlinkResolved])
    }
}
