// Copyright (c) 2022 Spotify AB.
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

class TextFileDependenciesRemapperTests: FileXCTestCase {

    let stringsRemapper = StringDependenciesRemapper(
        mappings: [
            .init(generic: "$(SRCROOT)", local: "/example")
        ])
    let fileAccessor = FileAccessorFake(mode: .strict)
    var remapper: TextFileDependenciesRemapper!

    override func setUp() {
        remapper = TextFileDependenciesRemapper(
            remapper: stringsRemapper,
            fileAccessor: fileAccessor
        )
    }

    func testRemapsGenericPlaceholders() throws {
        try fileAccessor.write(toPath: "/file", contents: "Some $(SRCROOT).")

        try remapper.remap(fromGeneric: "/file")

        try XCTAssertEqual(fileAccessor.contents(atPath: "/file"), "Some /example.")
    }

    func testRemapsLocalPathsToPlaceholders() throws {
        try fileAccessor.write(toPath: "/file", contents: "Some /example.")

        try remapper.remap(fromLocal: "/file")

        try XCTAssertEqual(fileAccessor.contents(atPath: "/file"), "Some $(SRCROOT).")
    }

    func testPersistsEmptyLines() throws {
        let multilineData = """
        Line1

        Line 2
        """.data(using: .utf8)
        try fileAccessor.write(toPath: "/file", contents: multilineData)

        try remapper.remap(fromGeneric: "/file")

        try XCTAssertEqual(fileAccessor.contents(atPath: "/file"), multilineData)
    }

    func testPersistsEmptyLineAtTheEnd() throws {
        let multilineData = """
        Line1

        Line 2
        
        """.data(using: .utf8)
        try fileAccessor.write(toPath: "/file", contents: multilineData)

        try remapper.remap(fromGeneric: "/file")

        try XCTAssertEqual(fileAccessor.contents(atPath: "/file"), multilineData)
    }

    func testReplacesMultipletimesInLine() throws {
        try fileAccessor.write(toPath: "/file", contents: "$(SRCROOT) and $(SRCROOT)")

        try remapper.remap(fromGeneric: "/file")

        try XCTAssertEqual(fileAccessor.contents(atPath: "/file"), "/example and /example")
    }

    func testReplacesInMultipleLine() throws {
        try fileAccessor.write(toPath: "/file", contents: "$(SRCROOT)\n$(SRCROOT)")

        try remapper.remap(fromGeneric: "/file")

        try XCTAssertEqual(fileAccessor.contents(atPath: "/file"), "/example\n/example")
    }
}
