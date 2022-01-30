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

class JsonOverlayReaderTests: XCTestCase {
    private static let resourcesSubdirectory = "TestData/Dependencies/JsonOverlayReaderTests"

    func testParsingWithSuccess() throws {
        let file = try pathForTestData(name: "overlayReaderDefault")
        let reader = JsonOverlayReader(file, mode: .strict, fileReader: FileManager.default)
        let mappings = try reader.provideMappings()

        let expectedMappings = [
            OverlayMapping(virtual: "/DerivedDataProducts/Target1.framework/Headers/Target1.h", local: "/Path/Target1/Target1.h"),
            OverlayMapping(virtual: "/DerivedDataProducts/Target2.framework/Modules/module.modulemap", local: "/DerivedDataIntermediate/Target2.build/module.modulemap")
        ]
        XCTAssertEqual(Set(mappings), Set(expectedMappings))
    }

    func testFailsWithMissingFileForStrictMode() throws {
        let file: URL = "nonExiting"
        let reader = JsonOverlayReader(file, mode: .strict, fileReader: FileManager.default)

        XCTAssertThrowsError(try reader.provideMappings())
    }

    func testReturnsEmpptyMappingForMissingFileForBestEffortMode() throws {
        let file: URL = "nonExiting"
        let reader = JsonOverlayReader(file, mode: .bestEffort, fileReader: FileManager.default)

        let mappings = try reader.provideMappings()

        XCTAssertEqual(mappings, [])
    }

    private func pathForTestData(name: String) throws -> URL {
        return try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: JsonOverlayReaderTests.resourcesSubdirectory))
    }
}
