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

class MD5Tests: XCTestCase {
    func testEmptyState() {
        let algorithm = MD5Algorithm()

        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testEmptyString() {
        let algorithm = MD5Algorithm()

        algorithm.add("")
        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testNoopForEmptyStrings() {
        let algorithm = MD5Algorithm()

        algorithm.add("")
        algorithm.add("")
        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testSingleHash() {
        let algorithm = MD5Algorithm()

        algorithm.add("The quick brown fox jumps over the lazy dog")
        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "9e107d9d372bb6826bd81d3542a419d6")
    }

    func testMultipleHash() {
        let algorithm = MD5Algorithm()

        algorithm.add("The quick brown fox jumps over the lazy dog")
        algorithm.add(".")

        let result = algorithm.finalizeString()

        XCTAssertEqual(result, "e4d909c290d0fb1ca068ffaddf22cbd0")
    }
}
