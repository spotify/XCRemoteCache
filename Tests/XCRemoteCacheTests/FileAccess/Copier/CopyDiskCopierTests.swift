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

class CopyDiskCopierTests: FileXCTestCase {
    private static let SampleData = "Sample".data(using: .utf8)!
    private var copier: CopyDiskCopier!
    private var workingDir: URL!
    private var emptySourceFile: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        workingDir = try prepareTempDir()
        emptySourceFile = workingDir.appendingPathComponent("source")
        try fileManager.spt_writeToFile(atPath: emptySourceFile.path, contents: Data())
        copier = CopyDiskCopier(fileManager: fileManager)
    }

    func testModifiedCopiedFileDoesntAffectDestinationContent() throws {
        let destinationFile = workingDir.appendingPathComponent("destination")

        try copier.copy(file: emptySourceFile, destination: destinationFile)
        try Self.SampleData.write(to: emptySourceFile)

        XCTAssertEqual(try Data(contentsOf: destinationFile), Data())
    }

    func testCreatesIntermediateDirs() throws {
        let destinationFile = workingDir
            .appendingPathComponent("parent")
            .appendingPathComponent("destination")

        try copier.copy(file: emptySourceFile, destination: destinationFile)

        XCTAssertTrue(fileManager.fileExists(atPath: destinationFile.path))
    }

    func testOverridesDestination() throws {
        let destinationFile = workingDir.appendingPathComponent("destination")
        try fileManager.spt_writeToFile(atPath: destinationFile.path, contents: Self.SampleData)

        try copier.copy(file: emptySourceFile, destination: destinationFile)

        XCTAssertEqual(try Data(contentsOf: destinationFile), Data())
    }
}
