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

class DependencyProcessorImplTests: XCTestCase {

    let processor = DependencyProcessorImpl(
        xcode: "/Xcode",
        product: "/Product",
        source: "/Source",
        intermediate: "/Intermediate",
        bundle: "/Bundle"
    )

    func testIntermediateFileIsSkippedForProductAndSourceSubdirectory() {
        let intermediateFile: URL = "/Intermediate/some"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/",
            source: "/",
            intermediate: "/Intermediate",
            bundle: nil
        )

        XCTAssertEqual(
            processor.process([intermediateFile]),
            []
        )
    }

    func testBundleFileIsSkippedForProductAndSourceSubdirectory() {
        let bundleFile: URL = "/Bundle/some"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/",
            source: "/",
            intermediate: "/Intermediate",
            bundle: "/Bundle"
        )

        XCTAssertEqual(
            processor.process([bundleFile]),
            []
        )
    }

    func testFiltersOutProductModulemap() throws {
        let dependencies = processor.process([
            "/Product/some.modulemap",
        ])

        XCTAssertEqual(dependencies, [])
    }

    func testDoesNotFilterOutNonProductModulemap() throws {
        let dependencies = processor.process([
            "/Source/some.modulemap",
        ])

        XCTAssertEqual(dependencies, [.init(url: "/Source/some.modulemap", type: .source)])
    }

    func testFiltersOutXcodeFiles() throws {
        let dependencies = processor.process([
            "/Xcode/some",
        ])

        XCTAssertEqual(dependencies, [])
    }

    func testFiltersOutIntermediateFiles() throws {
        let dependencies = processor.process([
            "/Intermediate/some",
        ])

        XCTAssertEqual(dependencies, [])
    }

    func testFiltersOutBundleFiles() throws {
        let dependencies = processor.process([
            "/Bundle/some",
        ])

        XCTAssertEqual(dependencies, [])
    }

    func testDoesNotFilterOutUnknownFiles() throws {
        let dependencies = processor.process([
            "/xxx/some",
        ])

        XCTAssertEqual(dependencies, [.init(url: "/xxx/some", type: .unknown)])
    }
}
