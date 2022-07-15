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

class UnzippedArtifactSwiftProductsOrganizerTests: XCTestCase {
    private let destination: URL = "/destination"
    private var artifactLocation: URL = "/artifact"
    private var generator: SwiftcProductsGeneratorSpy!
    private var dirAccessor: DirAccessor!
    private var syncer: FileFingerprintSyncer!
    private var organizer: UnzippedArtifactSwiftProductsOrganizer!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let destination = SwiftcProductsGeneratorOutput(swiftmoduleDir: destination, objcHeaderFile: "")
        generator = SwiftcProductsGeneratorSpy(generatedDestination: destination)
        dirAccessor = DirAccessorFake()
        syncer = FileFingerprintSyncer(
            fingerprintOverrideExtension: "md5",
            dirAccessor: dirAccessor,
            extensions: ["swiftmodule"]
        )
        organizer = UnzippedArtifactSwiftProductsOrganizer(
            arch: "arm64",
            moduleName: "MyName",
            artifactLocation: artifactLocation,
            productsGenerator: generator,
            fingerprintSyncer: syncer
        )
    }

    func testGeneratesFromValidFiles() throws {
        let expectedSourceSwiftmodule: URL = "/artifact/swiftmodule/arm64/MyName.swiftmodule"
        let expectedSourceSwiftdoc: URL = "/artifact/swiftmodule/arm64/MyName.swiftdoc"
        let expectedSourceObjCHeader: URL = "/artifact/include/arm64/MyName/MyName-Swift.h"

        try organizer.syncProducts(fingerprint: "1")

        XCTAssertEqual(generator.generated.count, 1)
        let generated = try XCTUnwrap(generator.generated.first)
        XCTAssertEqual(generated.0[.swiftmodule], expectedSourceSwiftmodule)
        XCTAssertEqual(generated.0[.swiftdoc], expectedSourceSwiftdoc)
        XCTAssertEqual(generated.1, expectedSourceObjCHeader)
    }

    func testGeneratesSwiftSourceinfoFromValidFile() throws {
        let expectedSwiftSourceInfo: URL = "/artifact/swiftmodule/arm64/MyName.swiftsourceinfo"

        try organizer.syncProducts(fingerprint: "1")

        XCTAssertEqual(generator.generated.count, 1)
        let generated = try XCTUnwrap(generator.generated.first)
        XCTAssertEqual(generated.0[.swiftsourceinfo], expectedSwiftSourceInfo)
    }

    func testDecoratesDestinationPath() throws {
        try dirAccessor.write(toPath: "/destination/MyName.swiftmodule", contents: Data())

        try organizer.syncProducts(fingerprint: "1")

        XCTAssertEqual(try dirAccessor.contents(atPath: "/destination/MyName.swiftmodule.md5"), "1".data(using: .utf8))
    }
}
