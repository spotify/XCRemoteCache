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

class ExceptionsFileListScannerTests: XCTestCase {

    private let checkURL = URL(fileURLWithPath: "/path/file.ext")

    func testAllowedFileIsAccepted() throws {
        let underlayingScanner = FileListScannerFake(files: [])
        let scanner = ExceptionsFilteredFileListScanner(
            allowedFilenames: ["file.ext"],
            disallowedFilenames: [],
            scanner: underlayingScanner
        )

        XCTAssertTrue(try scanner.contains(checkURL))
    }

    func testDisallowedFileIsBlocked() throws {
        let underlayingScanner = FileListScannerFake(files: [checkURL])
        let scanner = ExceptionsFilteredFileListScanner(
            allowedFilenames: [],
            disallowedFilenames: ["file.ext"],
            scanner: underlayingScanner
        )

        XCTAssertFalse(try scanner.contains(checkURL))
    }

    func testDisallowedPatternHasPriorityOverAllowedOne() throws {
        let underlayingScanner = FileListScannerFake(files: [checkURL])
        let scanner = ExceptionsFilteredFileListScanner(
            allowedFilenames: ["file.ext"],
            disallowedFilenames: ["file.ext"],
            scanner: underlayingScanner
        )

        XCTAssertFalse(try scanner.contains(checkURL))
    }
}
