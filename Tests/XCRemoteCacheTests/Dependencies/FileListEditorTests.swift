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

class FileListEditorTests: FileXCTestCase {

    func prepareFile(content: String, name: String = #function) throws -> URL {
        let directory = try prepareTempDir()
        let url = directory.appendingPathComponent(name)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testReadingFiles() throws {
        let content = """
        /tmp/file1.txt
        file2
        """
        let url = try prepareFile(content: content)
        let reader = FileListEditor(url, fileManager: FileManager.default)

        let readValue = try reader.listFilesURLs()

        XCTAssertEqual(Set(readValue), Set([
            URL(fileURLWithPath: "/tmp/file1.txt"),
            URL(fileURLWithPath: "file2"),
        ]))
    }

    func testReadingFilesWithSpaces() throws {
        let content = """
        /file2\\ with.space
        """
        let url = try prepareFile(content: content)
        let reader = FileListEditor(url, fileManager: FileManager.default)

        let readValue = try reader.listFilesURLs()

        XCTAssertEqual(Set(readValue), Set([
            URL(fileURLWithPath: "/file2 with.space"),
        ]))
    }

    func testReadingNonExistingFileThrowsError() throws {
        let url = URL(fileURLWithPath: "non_existing")
        let reader = FileListEditor(url, fileManager: FileManager.default)

        XCTAssertThrowsError(try reader.listFilesURLs())
    }

    func testWritingFile() throws {
        let url: URL = "/file2.swift"
        let expectedContent = """
        /file2.swift
        """
        let fileURL = try prepareFile(content: "")
        let reader = FileListEditor(fileURL, fileManager: FileManager.default)

        try reader.writerListFilesURLs([url])

        try XCTAssertEqual(String(contentsOf: fileURL), expectedContent)
    }

    func testWritingFileWithSpace() throws {
        let url: URL = "/file2 with.space"
        let expectedContent = """
        /file2\\ with.space
        """
        let fileURL = try prepareFile(content: "")
        let reader = FileListEditor(fileURL, fileManager: FileManager.default)

        try reader.writerListFilesURLs([url])

        try XCTAssertEqual(String(contentsOf: fileURL), expectedContent)
    }
}
