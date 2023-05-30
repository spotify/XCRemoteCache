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

class SwiftcFilemapInputEditorTests: FileXCTestCase {
    private let sampleInfo = SwiftCompilationInfo(
        info: SwiftModuleCompilationInfo(
        dependencies: nil,
        swiftDependencies: "/"
    ), files: [])
    private let file = SwiftFileCompilationInfo(
        file: "/file1",
        dependencies: nil,
        object: "/file3",
        swiftDependencies: nil
    )
    private let sampleInfoContentData = #"{"":{"swift-dependencies":"/"}}"#.data(using: .utf8)!
    private var inputFile: URL!
    private var editorJson: SwiftcFilemapInputEditor!
    private var editorYaml: SwiftcFilemapInputEditor!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try prepareTempDir()
        inputFile = workingDirectory!.appendingPathComponent("swift.json")
        editorJson = SwiftcFilemapInputEditor(inputFile, fileFormat: .json, fileManager: fileManager)
        editorYaml = SwiftcFilemapInputEditor(inputFile, fileFormat: .yaml, fileManager: fileManager)
    }

    func testReading() throws {
        try fileManager.spt_writeToFile(atPath: inputFile.path, contents: sampleInfoContentData)

        let readInfo = try editorJson.read()

        XCTAssertEqual(readInfo, sampleInfo)
    }

    func testReadingInfoWithOptionalProperties() throws {
        let infoContentData = #"""
        {
           "":{
              "swift-dependencies":"/master.swiftdeps",
              "dependencies":"/master.d"
           },
           "/file1.swift":{
              "dependencies":"/file1.d",
              "object":"/file1.o",
              "swift-dependencies":"/file1.swiftdeps"
           }
        }
        """#.data(using: .utf8)!
        let expectedInfo = SwiftCompilationInfo(
            info: SwiftModuleCompilationInfo(
                dependencies: "/master.d",
                swiftDependencies: "/master.swiftdeps"
            ),
            files: [
                SwiftFileCompilationInfo(
                    file: "/file1.swift",
                    dependencies: "/file1.d",
                    object: "/file1.o",
                    swiftDependencies: "/file1.swiftdeps"
                ),
            ])
        try fileManager.spt_writeToFile(atPath: inputFile.path, contents: infoContentData)

        let readInfo = try editorJson.read()

        XCTAssertEqual(readInfo, expectedInfo)
    }

    func testWritingSavesContent() throws {
        try editorJson.write(sampleInfo)

        let savedContent = try Data(contentsOf: inputFile)
        let content = try JSONSerialization.jsonObject(with: savedContent, options: []) as? [String: Any]
        let contentDict = try XCTUnwrap(content)
        try XCTAssertEqual(SwiftCompilationInfo(from: contentDict), sampleInfo)
    }

    func testWritingSavesContentWithOptionalParameters() throws {
        let extendedInfo = SwiftCompilationInfo(
            info: SwiftModuleCompilationInfo(
                dependencies: "/master.d",
                swiftDependencies: "/master.swiftdeps"
            ), files: [
                SwiftFileCompilationInfo(
                    file: "/file1.swift",
                    dependencies: "/file1.d",
                    object: "/file1.o",
                    swiftDependencies: "/file1.swiftdeps"
                ),
            ])

        try editorJson.write(extendedInfo)

        let savedContent = try Data(contentsOf: inputFile)
        let content = try JSONSerialization.jsonObject(with: savedContent, options: []) as? [String: Any]
        let contentDict = try XCTUnwrap(content)
        try XCTAssertEqual(SwiftCompilationInfo(from: contentDict), extendedInfo)
    }

    func testModifyingFileCompilationInfo() throws {
        try fileManager.spt_writeToFile(atPath: inputFile.path, contents: sampleInfoContentData)

        let originalInfo = try editorJson.read()
        var modifiedInfo = originalInfo
        modifiedInfo.files = [file]
        try editorJson.write(modifiedInfo)
        let finalInfo = try editorJson.read()

        XCTAssertEqual(finalInfo, modifiedInfo)
    }

    func testReadingSupplementaryInfoWithOptionalProperties() throws {
        let infoContentData = #"""
        "/file1.swift":
          swift-dependencies: "/file1.swiftdeps"
          dependencies: "/file1.d"
        "/file2.swift":
          dependencies: "/file2.d"
          object: "/file2.o"
          swift-dependencies: "/file2.swiftdeps"
        """#.data(using: .utf8)!
        let expectedInfo = SwiftCompilationInfo(
            info: SwiftModuleCompilationInfo(
                dependencies: nil,
                swiftDependencies: nil
            ),
            files: [
                SwiftFileCompilationInfo(
                    file: "/file1.swift",
                    dependencies: "/file1.d",
                    object: nil,
                    swiftDependencies: "/file1.swiftdeps"
                ),
                SwiftFileCompilationInfo(
                    file: "/file2.swift",
                    dependencies: "/file2.d",
                    object: "/file2.o",
                    swiftDependencies: "/file2.swiftdeps"
                ),
            ])
        try fileManager.spt_writeToFile(atPath: inputFile.path, contents: infoContentData)

        let readInfo = try editorYaml.read()

        // `files` order doesn't match
        XCTAssertEqual(readInfo.info, expectedInfo.info)
        XCTAssertEqual(Set(readInfo.files), Set(expectedInfo.files))
    }
}
