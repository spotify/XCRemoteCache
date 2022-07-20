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

class ReplicatedRemotesNetworkClientTests: XCTestCase {

    private let fileManager = FileManager.default
    private var networkClient: NetworkClientFake!
    private var localSampleFile: URL!
    private var downloadURL: URL!
    private var uploadURLs: [URL]!
    private var download: URLBuilder!
    private var uploads: [URLBuilder]!
    private var client: RemoteNetworkClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        networkClient = NetworkClientFake(fileManager: fileManager)
        localSampleFile = try prepareLocalEmptyFile()
        downloadURL = try URL(string: "http://download.com").unwrap()
        uploadURLs = try [URL(string: "http://upload1.com").unwrap(), URL(string: "http://upload2.com").unwrap()]
        download = URLBuilderFake(downloadURL)
        uploads = uploadURLs.map(URLBuilderFake.init)
        client = ReplicatedRemotesNetworkClient(
            networkClient,
            download: download,
            uploads: uploads,
            uploadBatchSize: 1
        )
    }

    private func prepareLocalEmptyFile() throws -> URL {
        let testName = try (testRun?.test.name).unwrap()
        let url = fileManager.temporaryDirectory.appendingPathComponent(testName)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        fileManager.createFile(atPath: url.path, contents: Data(), attributes: nil)
        return url
    }

    func testUploadsToAllStreams() throws {
        let expectedArtifact1 = try URL(string: "http://upload1.com/file/id1").unwrap()
        let expectedArtifact2 = try URL(string: "http://upload2.com/file/id1").unwrap()

        try client.uploadSynchronously(localSampleFile, as: .artifact(id: "id1"))

        XCTAssertTrue(try networkClient.fileExistsSynchronously(expectedArtifact1))
        XCTAssertTrue(try networkClient.fileExistsSynchronously(expectedArtifact2))
    }

    func testUploadsWithLimit() throws {
        var expectedArtifacts = [URL]()
        var uploadURLs = [URL]()
        for index in 0...99 {
            let expectedArtifact = try URL(string: "http://upload\(index).com/file/id1").unwrap()
            expectedArtifacts.append(expectedArtifact)
            let uploadURL = try URL(string: "http://upload\(index).com").unwrap()
            uploadURLs.append(uploadURL)
        }
        uploads = uploadURLs.map(URLBuilderFake.init)
        client = ReplicatedRemotesNetworkClient(
            networkClient,
            download: download,
            uploads: uploads,
            uploadBatchSize: 10
        )

        try client.uploadSynchronously(localSampleFile, as: .artifact(id: "id1"))

        for expectedArtifact in expectedArtifacts {
            XCTAssertTrue(try networkClient.fileExistsSynchronously(expectedArtifact))
        }
    }

    func testCreatesInAllStreams() throws {
        let expectedMeta1 = try URL(string: "http://upload1.com/meta/commit_id").unwrap()
        let expectedMeta2 = try URL(string: "http://upload2.com/meta/commit_id").unwrap()

        try client.createSynchronously(.meta(commit: "commit_id"))

        XCTAssertTrue(try networkClient.fileExistsSynchronously(expectedMeta1))
        XCTAssertTrue(try networkClient.fileExistsSynchronously(expectedMeta2))
    }

}
