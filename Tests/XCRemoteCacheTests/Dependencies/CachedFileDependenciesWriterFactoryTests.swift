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


class CachedFileDependenciesWriterFactoryTests: XCTestCase {
    private var fileManager: FileManager!
    private var workingDir: URL!
    private var writerSpy: DependenciesWriterSpy!
    private var factory: ((URL, FileManager) -> DependenciesWriter)!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let fileManager = FileManager.default
        self.fileManager = fileManager
        workingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(#file)
        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true, attributes: nil)

        let writerSpy = DependenciesWriterSpy()
        self.writerSpy = writerSpy
        factory = { [fileManager, writerSpy] file, _ in
            fileManager.createFile(atPath: file.path, contents: nil, attributes: nil)
            return writerSpy
        }
    }

    override func tearDownWithError() throws {
        try fileManager.removeItem(at: workingDir)
        workingDir = nil
        fileManager = nil
        try super.tearDownWithError()
    }


    func testGeneratesFirstContent() throws {
        let url1 = workingDir.appendingPathComponent("file1")
        let cachedFactory =
            CachedFileDependenciesWriterFactory(dependencies: [url1], fileManager: fileManager, writerFactory: factory)

        try cachedFactory.generate(output: url1)

        XCTAssertEqual(writerSpy.wroteDependencies, ["dependencies": [url1.path]])
    }

    func testReusesOnceGeneratedContent() throws {
        let url1 = workingDir.appendingPathComponent("file1")
        let url2 = workingDir.appendingPathComponent("file2")
        let cachedFactory =
            CachedFileDependenciesWriterFactory(dependencies: [], fileManager: fileManager, writerFactory: factory)

        try cachedFactory.generate(output: url1)
        try writerSpy.write(dependencies: ["custom": ["1"]])
        try cachedFactory.generate(output: url2)

        // Verify that writerSpy didn't get a call from cachedFactory (which passes an empty array of dependencies)
        XCTAssertEqual(writerSpy.wroteDependencies, ["custom": ["1"]])
    }
}
