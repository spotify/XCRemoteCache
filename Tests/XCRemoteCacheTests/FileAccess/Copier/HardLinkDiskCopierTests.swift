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

class HardLinkDiskCopierTests: FileXCTestCase {
    private static let SampleData = "Sample".data(using: .utf8)!

    func testCopiesFileToDir() throws {
        let workingDir = try prepareTempDir()
        let destinationDir = try fileManager.spt_createEmptyDir(workingDir.appendingPathComponent("dest"))
        let expectedDestinationFile = destinationDir.appendingPathComponent("empty.txt")
        let file = try fileManager.spt_createEmptyFile(workingDir.appendingPathComponent("empty.txt"))
        try fileManager.spt_createEmptyDir(destinationDir)
        let copier = HardLinkDiskCopier(fileManager: fileManager)

        try copier.copy(file: file, directory: destinationDir)

        XCTAssertTrue(fileManager.fileExists(atPath: expectedDestinationFile.path))
    }

    func testModifiedCopiedFileAffectsDestinationContent() throws {
        let workingDir = try prepareTempDir()
        let sourceFile = workingDir.appendingPathComponent("source")
        let destinationFile = workingDir.appendingPathComponent("destination")
        try fileManager.spt_writeToFile(atPath: sourceFile.path, contents: Data())
        let copier = HardLinkDiskCopier(fileManager: fileManager)

        try copier.copy(file: sourceFile, destination: destinationFile)
        try Self.SampleData.write(to: sourceFile)

        XCTAssertEqual(try Data(contentsOf: destinationFile), Self.SampleData)
    }
}
