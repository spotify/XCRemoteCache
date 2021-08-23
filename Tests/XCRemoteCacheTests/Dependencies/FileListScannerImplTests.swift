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

class FileListScannerImplTests: XCTestCase {
    private let sampleURL = URL(fileURLWithPath: "/sampleURL")

    func testFileListFindsURL() {
        let listReader = ListReaderMock([sampleURL])
        let scanner = FileListScannerImpl(listReader, caseSensitive: true)

        XCTAssertTrue(try scanner.contains(sampleURL))
    }

    func testFileListFindsURLCaseSensitive() {
        let listReader = ListReaderMock([sampleURL])
        let scanner = FileListScannerImpl(listReader, caseSensitive: true)

        XCTAssertFalse(try scanner.contains(URL(fileURLWithPath: "/sampleurl")))
    }

    func testFileListReturnsFalseForNotFoundURL() {
        let listReader = ListReaderMock([sampleURL])
        let scanner = FileListScannerImpl(listReader, caseSensitive: true)

        XCTAssertFalse(try scanner.contains(URL(fileURLWithPath: "/otherURL")))
    }

    func testFileListFindsURLCaseInsensitive() {
        let listReader = ListReaderMock([sampleURL])
        let scanner = FileListScannerImpl(listReader, caseSensitive: false)

        XCTAssertTrue(try scanner.contains(URL(fileURLWithPath: "/sampleurl")))
    }
}

private class ListReaderMock: ListReader {
    private let urls: [URL]
    init(_ urls: [URL]) {
        self.urls = urls
    }

    func listFilesURLs() throws -> [URL] {
        return urls
    }

    func canRead() -> Bool {
        return true
    }
}
