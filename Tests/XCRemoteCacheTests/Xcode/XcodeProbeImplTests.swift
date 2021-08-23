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


class XcodeProbeImplTests: XCTestCase {

    private func generateOutput(returnString: String) -> ShellOutFunction {
        return { _, _, _, _ in returnString }
    }

    func testValidOutput() throws {
        let outputString = """
        Xcode 11.3.1
        Build version 11C505
        """
        let probe = XcodeProbeImpl(shell: generateOutput(returnString: outputString))

        let version = try probe.read()

        XCTAssertEqual(version.buildVersion, "11C505")
        XCTAssertEqual(version.version, "11.3.1")
    }

    func testFailingForInvalidOutput() throws {
        let outputString = ""
        let probe = XcodeProbeImpl(shell: generateOutput(returnString: outputString))

        XCTAssertThrowsError(try probe.read())
    }
}
