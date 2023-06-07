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
        derivedFiles: "/DerivedFiles",
        bundle: "/Bundle",
        skippedRegexes: []
    )

    func testIntermediateFileIsskippedRegexesForProductAndSourceSubdirectory() {
        let intermediateFile: URL = "/Intermediate/some"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/",
            source: "/",
            intermediate: "/Intermediate",
            derivedFiles: "/DerivedFiles",
            bundle: nil,
            skippedRegexes: []
        )

        XCTAssertEqual(
            processor.process([intermediateFile]).fingerprintScoped,
            []
        )
    }

    func testBundleFileIsskippedRegexesForProductAndSourceSubdirectory() {
        let bundleFile: URL = "/Bundle/some"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/",
            source: "/",
            intermediate: "/Intermediate",
            derivedFiles: "/DerivedFiles",
            bundle: "/Bundle",
            skippedRegexes: []
        )

        XCTAssertEqual(
            processor.process([bundleFile]).fingerprintScoped,
            []
        )
    }

    func testFiltersOutGeneratedSwiftHeaders() throws {
        let dependencies = processor.process([
            "/DerivedFiles/ModuleName-Swift.h",
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [])
    }

    func testFiltersOutDerivedFile() throws {
        let dependencies = processor.process([
            "/DerivedFiles/output.h",
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [])
    }

    func testFiltersOutProductModulemap() throws {
        let dependencies = processor.process([
            "/Product/some.modulemap",
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [])
    }

    func testDoesNotFilterOutOtherProductModulemap() throws {
        let dependencies = processor.process([
            "/ProductOther/some.modulemap",
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [.init(url: "/ProductOther/some.modulemap", type: .unknown)])
    }

    func testDoesNotFilterOutNonProductModulemap() throws {
        let dependencies = processor.process([
            "/Source/some.modulemap",
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [.init(url: "/Source/some.modulemap", type: .source)])
    }

    func testFiltersOutXcodeFiles() throws {
        let dependencies = processor.process([
            "/Xcode/some",
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [])
    }

    func testFiltersOutIntermediateFiles() throws {
        let dependencies = processor.process([
            "/Intermediate/some",
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [])
    }

    func testFiltersOutBundleFiles() throws {
        let dependencies = processor.process([
            "/Bundle/some",
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [])
    }

    func testDoesNotFilterOutUnknownFiles() throws {
        let dependencies = processor.process([
            "/xxx/some",
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [.init(url: "/xxx/some", type: .unknown)])
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
            derivedFiles: "/DerivedFiles",
            bundle: "/Bundle",
            skippedRegexes: []
        )

        let intermediateFileSymlink = createSymlink(
            filename: someFilename,
            sourceDir: symlink,
            destinationDir: intermediateDirReal
        )

        let dependencies = processor.process([
            intermediateFileSymlink,
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [])
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
            derivedFiles: "/DerivedFiles",
            bundle: "/Bundle",
            skippedRegexes: []
        )

        let sourceFileSymlink = createSymlink(
            filename: someFilename,
            sourceDir: symlink,
            destinationDir: sourceDirReal
        )

        let dependencies = processor.process([
            sourceFileSymlink,
        ])

        XCTAssertEqual(dependencies.fingerprintScoped, [.init(url: sourceFileSymlink, type: .source)])
    }

    /**
     * Creates Symlink from sourceDir to destinationDir and creates empty file inside it
     * return URL with symbolic link from sourceDir to destinationDir
     */
    fileprivate func createSymlink(filename: String, sourceDir: URL, destinationDir: URL) -> URL {
        let fileMng = FileManager.default

        XCTAssertNoThrow(try fileMng.spt_forceSymbolicLink(
            at: sourceDir,
            withDestinationURL: destinationDir
        ))
        XCTAssertNoThrow(try fileMng.spt_createEmptyFile(destinationDir.appendingPathComponent(filename)))

        return sourceDir.appendingPathComponent(filename)
    }

    func testSkipsCustomizedDerivedDirFileUnderSources() {
        let derivedFile: URL = "/DerivedFiles/Module-Swift.h"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/",
            source: "/",
            intermediate: "/Intermediate",
            derivedFiles: "/DerivedFiles",
            bundle: nil,
            skippedRegexes: []
        )

        XCTAssertEqual(
            processor.process([derivedFile]).fingerprintScoped,
            []
        )
    }

    func testSkippsFilesWithFullMatch() {
        let source: URL = "/someFile.m"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/",
            source: "/",
            intermediate: "/Intermediate",
            derivedFiles: "/DerivedFiles",
            bundle: nil,
            skippedRegexes: ["/someFile\\.m"]
        )

        XCTAssertEqual(
            processor.process([source]).fingerprintScoped,
            []
        )
    }

    func testSkippsFilesWithPartialMatch() {
        let derivedModulemap: URL = "/module.modulemap"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/product",
            source: "/",
            intermediate: "/Intermediate",
            derivedFiles: "/DerivedFiles",
            bundle: nil,
            skippedRegexes: ["\\.modulemap$"]
        )

        XCTAssertEqual(
            processor.process([derivedModulemap]).fingerprintScoped,
            []
        )
    }

    func testDoesntSkipFileIfInvalidRegex() {
        let source: URL = "/someFile.m"
        let processor = DependencyProcessorImpl(
            xcode: "/Xcode",
            product: "/product",
            source: "/",
            intermediate: "/Intermediate",
            derivedFiles: "/DerivedFiles",
            bundle: nil,
            skippedRegexes: ["\\"]
        )

        XCTAssertEqual(
            processor.process([source]).fingerprintScoped,
            [.init(url: source, type: .source)]
        )
    }
}
