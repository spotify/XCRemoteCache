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

class URLBuilderImplTests: XCTestCase {

    func testTwoMarkersForOtherSchemasAreDifferent() throws {
        let sampleURL = try XCTUnwrap(URL(string: "https://example.com"))
        let builder1 = URLBuilderImpl(
            address: sampleURL,
            configuration: "",
            platform: "",
            targetName: "",
            xcode: "",
            envFingerprint: "",
            schemaVersion: "1"
        )
        let builder2 = URLBuilderImpl(
            address: sampleURL,
            configuration: "",
            platform: "",
            targetName: "",
            xcode: "",
            envFingerprint: "",
            schemaVersion: "2"
        )

        XCTAssertNotEqual(
            try builder1.location(for: .marker(commit: "a")),
            try builder2.location(for: .marker(commit: "a"))
        )
    }
}
