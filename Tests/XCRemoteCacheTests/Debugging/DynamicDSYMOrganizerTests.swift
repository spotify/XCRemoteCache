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

class DynamicDSYMOrganizerTests: FileXCTestCase {
    struct ShellCall: Equatable {
        let command: String
        let args: [String]
    }

    private var shellCommands: [ShellCall] = []
    private var shell: ShellCallFunction!
    private let productURL: URL = "product"
    private var dSYMPath: URL!


    override func setUpWithError() throws {
        try super.setUpWithError()
        dSYMPath = try prepareTempDir().appendingPathComponent("dsym")
        shell = { command, args, _, _ in
            self.shellCommands.append(ShellCall(command: command, args: args))
        }
    }

    override func tearDown() {
        shell = nil
        super.tearDown()
    }

    func testGeneratesDsymWhenWasntAlreadyProduced() throws {
        let expectedCommand = ShellCall(command: "dsymutil", args: [productURL.path, "-o", dSYMPath.path])
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .dynamicLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: false,
            fileManager: .default,
            shellCall: shell
        )

        let generatedDSYM = try organizer.relevantDSYMLocation()

        XCTAssertEqual(shellCommands, [expectedCommand])
        XCTAssertEqual(generatedDSYM, dSYMPath)
    }

    func testDoesntGenerateDsymWhenWasAlreadyProduced() throws {
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .dynamicLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: true,
            fileManager: .default,
            shellCall: shell
        )

        let generatedDSYM = try organizer.relevantDSYMLocation()

        XCTAssertEqual(shellCommands, [])
        XCTAssertEqual(generatedDSYM, dSYMPath)
    }

    func testCleanupHappensDeletesdSym() throws {
        fileManager.createFile(atPath: dSYMPath.path, contents: nil, attributes: nil)
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .dynamicLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: false,
            fileManager: .default,
            shellCall: shell
        )

        try organizer.cleanup()

        XCTAssertFalse(fileManager.fileExists(atPath: dSYMPath.path))
    }

    func testCleanupDoesntDeleteExternallyCreatedDsym() throws {
        fileManager.createFile(atPath: dSYMPath.path, contents: nil, attributes: nil)
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .dynamicLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: true,
            fileManager: .default,
            shellCall: shell
        )

        try organizer.cleanup()

        XCTAssertTrue(fileManager.fileExists(atPath: dSYMPath.path))
    }

    func testDoesntCreateDSymForStaticLib() throws {
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .staticLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: false,
            fileManager: .default,
            shellCall: shell
        )

        XCTAssertNil(try organizer.relevantDSYMLocation())
    }
}
