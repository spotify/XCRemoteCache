// Copyright (c) 2023 Spotify AB.
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

class AssetsFileDependenciesReaderTests: FileXCTestCase {
    private static let resourcesSubdirectory = "TestData/Dependencies/AssetsFileDependenciesReaderTests"
    private let dirAccessorFake = DirAccessorFake()

    private func pathForTestData(name: String) throws -> URL {
        return try XCTUnwrap(Bundle.module.url(
            forResource: name,
            withExtension: "",
            subdirectory: AssetsFileDependenciesReaderTests.resourcesSubdirectory
        ))
    }

    func testParsingSampleFile() throws {
        let file = try pathForTestData(name: "assetcatalog_dependencies_sample")
        let fileData = try Data(contentsOf: file)
        let xcassetsPath: URL = "/StandaloneApp/Assets.xcassets"
        let contentsJson = xcassetsPath.appendingPathComponent("Contents.json")

        try dirAccessorFake.write(toPath: file.path, contents: fileData)
        try dirAccessorFake.write(toPath: contentsJson.path, contents: Data())

        let reader = AssetsFileDependenciesReader(file, dirAccessor: dirAccessorFake)

        let dependencies = try reader.findDependencies()

        XCTAssertEqual(dependencies, [contentsJson.path])
    }

    func testThrowsWhenFileIsMissing() throws {
        let file: URL = "/nonExistingFile"

        let reader = AssetsFileDependenciesReader(file, dirAccessor: dirAccessorFake)

        XCTAssertThrowsError(try reader.findDependencies())  { error in
            guard case DependenciesReaderError.readingError = error else {
                XCTFail("Invalid error \(error)")
                return
            }
        }
    }

    func testReturnsEmptyArrayIsFileIsMalformed() throws {
        let file: URL = "/nonExistingFile"
        try dirAccessorFake.write(toPath: file.path, contents: Data())
        let reader = AssetsFileDependenciesReader(file, dirAccessor: dirAccessorFake)

        let dependencies = try reader.findDependencies()

        XCTAssertEqual(dependencies, [])
    }
}
