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

class IncludeExcludeOracleTests: XCTestCase {

    func testExcludes() {
        let oracle = IncludeExcludeOracle(excludes: ["extra"], includes: [])

        XCTAssertFalse(oracle.shouldInclude(identifier: "extra"))
        XCTAssertTrue(oracle.shouldInclude(identifier: "applicable"))
    }

    func testEmptyIncludeAcceptsAllIdentifiers() {
        let oracle = IncludeExcludeOracle(excludes: [], includes: [])

        XCTAssertTrue(oracle.shouldInclude(identifier: "random"))
    }

    func testIncludesOnlyExplicitIdentifiers() {
        let oracle = IncludeExcludeOracle(excludes: [], includes: ["explicit"])

        XCTAssertFalse(oracle.shouldInclude(identifier: "other"))
        XCTAssertTrue(oracle.shouldInclude(identifier: "explicit"))
    }

    func testExcludeHasHigherPriority() {
        let oracle = IncludeExcludeOracle(excludes: ["explicit"], includes: ["explicit"])

        XCTAssertFalse(oracle.shouldInclude(identifier: "explicit"))
    }
}
