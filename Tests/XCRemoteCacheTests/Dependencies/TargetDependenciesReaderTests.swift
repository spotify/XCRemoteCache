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

class TargetDependenciesReaderTests: XCTestCase {

    private let workingURL: URL = "/test"
    private var dirAccessor: DirAccessorFake!
    private var reader: TargetDependenciesReader!

    override func setUp() {
        dirAccessor = DirAccessorFake()
        /// A Factory that builds a faked dependency reader that returns a single dependency,
        /// a basename of the input .d file and the ".swift" extension
        let swiftFakeDependencyReaderFactory: (URL) -> DependenciesReader = { url in
            let fakeDependency = url.deletingPathExtension().appendingPathExtension("swift")
            return DependenciesReaderFake(dependencies: ["": [fakeDependency.path]])
        }
        reader = TargetDependenciesReader(
            workingURL,
            fileDependeciesReaderFactory: swiftFakeDependencyReaderFactory,
            dirScanner: dirAccessor
        )
    }

    func testFindsIncrementalDependencies() throws {
        let dFile: URL = "/test/some.d"
        let oFile: URL = "/test/some.o"
        try dirAccessor.write(toPath: dFile.path, contents: Data())
        try dirAccessor.write(toPath: oFile.path, contents: Data())

        let deps = try reader.findDependencies()

        XCTAssertEqual(deps, ["/test/some.swift"])
    }

    func testSkipsFindingDependenciesWhenOFileIsNotPresent() throws {
        let dFile: URL = "/test/some.d"
        try dirAccessor.write(toPath: dFile.path, contents: Data())

        let deps = try reader.findDependencies()

        XCTAssertEqual(deps, [])
    }

    func testFindsWMODependency() throws {
        let dFile: URL = "/test/some-master.d"
        try dirAccessor.write(toPath: dFile.path, contents: Data())

        let deps = try reader.findDependencies()

        XCTAssertEqual(deps, ["/test/some-master.swift"])
    }
}
