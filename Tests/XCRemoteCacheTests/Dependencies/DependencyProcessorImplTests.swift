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

class DependencyProcessorImplTests: FileXCTestCase {

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

    func testDoesNotFilterOutOtherProductModulemap() throws {
        let dependencies = processor.process([
            "/ProductOther/some.modulemap",
        ])

        XCTAssertEqual(dependencies, [.init(url: "/ProductOther/some.modulemap", type: .unknown)])
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

    func testFiltersOutIntermediateBySymlink() throws {
        let sampleDir = try prepareTempDir()

        let intermediateDirReal = sampleDir.appendingPathComponent("Intermediate")
        let symlink = sampleDir.appendingPathComponent("symlink")
        let someFilename = "some"

        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/Product",
            source: "/Source",
            intermediate: intermediateDirReal,
            bundle: "/Bundle"
        )

        let intermediateFileSymlink = createSymlink(filename: someFilename, sourceDir: symlink, destinationDir: intermediateDirReal)

        let dependencies = processor.process([
            intermediateFileSymlink
        ])

        XCTAssertEqual(dependencies, [])
    }

    func testDoesNotFilterOutSourceBySymlink() throws {
        let sampleDir = try prepareTempDir()

        let sourceDirReal = sampleDir.appendingPathComponent("Source")
        let symlink = sampleDir.appendingPathComponent("symlink")
        let someFilename = "some"

        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/Product",
            source: sourceDirReal,
            intermediate: "/Intermediate",
            bundle: "/Bundle"
        )

        let sourceFileSymlink = createSymlink(filename: someFilename, sourceDir: symlink, destinationDir: sourceDirReal)

        let dependencies = processor.process([
            sourceFileSymlink
        ])

        XCTAssertEqual(dependencies, [.init(url: sourceFileSymlink, type: .source)])
    }

    /**
     * Creates Symlink from sourceDir to destinationDir and creates empty file inside it
     * return URL with symbolic link from sourceDir to destinationDir
     */
    fileprivate func createSymlink(filename: String, sourceDir: URL, destinationDir: URL) -> URL {
        let fileMng = FileManager.default

        XCTAssertNoThrow(try fileMng.spt_forceSymbolicLink(at: sourceDir,
                                                           withDestinationURL: destinationDir))
        XCTAssertNoThrow(try fileMng.spt_createEmptyFile(destinationDir.appendingPathComponent(filename)))

        return sourceDir.appendingPathComponent(filename)
    }
}
