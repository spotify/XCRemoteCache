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

class FileMarkerReaderTests: XCTestCase {

    func buildTempFile(content: String) throws -> URL {
        let directory = NSTemporaryDirectory()
        let url = try NSURL.fileURL(withPathComponents: [directory, name]).unwrap()
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testReading() throws {
        let url = try buildTempFile(content: """
        dependencies: \\
        /file1.m \\
        /Some/Path.file2.h
        """)
        let reader = FileMarkerReader(url, fileManager: FileManager.default)

        let readValue = try reader.listFilesURLs()

        XCTAssertEqual(Set(readValue), Set(["/file1.m", "/Some/Path.file2.h"].map(URL.init(fileURLWithPath:))))
    }

    func testReadingEmptyMarker() throws {
        let url = try buildTempFile(content: """
        dependencies: \\
        """)
        let reader = FileMarkerReader(url, fileManager: FileManager.default)

        let readValue = try reader.listFilesURLs()

        XCTAssertEqual(readValue, [])
    }
}
