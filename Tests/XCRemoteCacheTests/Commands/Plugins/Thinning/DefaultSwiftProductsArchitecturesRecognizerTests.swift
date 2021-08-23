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

class DefaultSwiftProductsArchitecturesRecognizerTests: FileXCTestCase {
    private var recognizer: DefaultSwiftProductsArchitecturesRecognizer!
    private var builtProductsDir: URL!
    private var swiftmoduleDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        recognizer = DefaultSwiftProductsArchitecturesRecognizer(dirAccessor: fileManager)
        builtProductsDir = try prepareTempDir().appendingPathComponent("builtProductsDir")
        swiftmoduleDir = builtProductsDir
            .appendingPathComponent("MyModule.swiftmodule")
    }

    func testRecognizesArchitecutres() throws {
        let swiftmoduleFile = swiftmoduleDir.appendingPathComponent("x86.swiftmodule")
        try fileManager.spt_createEmptyFile(swiftmoduleFile)

        let architectures = try recognizer.recognizeArchitectures(
            builtProductsDir: builtProductsDir,
            moduleName: "MyModule"
        )

        XCTAssertEqual(architectures, ["x86"])
    }

    func testRecognizesMultipleArchitecutres() throws {
        let swiftmoduleFile = swiftmoduleDir.appendingPathComponent("x86.swiftmodule")
        try fileManager.spt_createEmptyFile(swiftmoduleFile)
        let swiftmoduleSimFile = swiftmoduleDir.appendingPathComponent("x86_64-apple-ios-simulator.swiftmodule")
        try fileManager.spt_createEmptyFile(swiftmoduleSimFile)

        let architectures = try recognizer.recognizeArchitectures(
            builtProductsDir: builtProductsDir,
            moduleName: "MyModule"
        )

        XCTAssertEqual(architectures, ["x86", "x86_64-apple-ios-simulator"])
    }

    func testRecognizedArchitecutresAreNotDuplciated() throws {
        let swiftmodule = swiftmoduleDir.appendingPathComponent("x86.swiftmodule")
        let swiftmoduleDocs = swiftmoduleDir.appendingPathComponent("x86.swiftdocs")
        try fileManager.spt_createEmptyFile(swiftmodule)
        try fileManager.spt_createEmptyFile(swiftmoduleDocs)

        let architectures = try recognizer.recognizeArchitectures(
            builtProductsDir: builtProductsDir,
            moduleName: "MyModule"
        )

        XCTAssertEqual(architectures, ["x86"])
    }

    func testRecognizesArchitectureFromOverridesFiles() throws {
        let swiftmoduleMd5 = swiftmoduleDir.appendingPathComponent("x86.swiftmodule.md5")
        try fileManager.spt_createEmptyFile(swiftmoduleMd5)

        let architectures = try recognizer.recognizeArchitectures(
            builtProductsDir: builtProductsDir,
            moduleName: "MyModule"
        )

        XCTAssertEqual(architectures, ["x86"])
    }
}
