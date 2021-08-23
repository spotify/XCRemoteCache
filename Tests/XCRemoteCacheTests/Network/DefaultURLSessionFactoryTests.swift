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

class DefaultURLSessionFactoryTests: XCTestCase {

    private var exampleURL: URL!
    private var config: XCRemoteCacheConfig!

    override func setUpWithError() throws {
        try super.setUpWithError()
        exampleURL = try URL(string: "http://example.com").unwrap()
        config = XCRemoteCacheConfig(sourceRoot: ".")
    }

    override func tearDown() {
        config = nil
        exampleURL = nil
        super.tearDown()
    }


    func testSessionSetsExtraHeaders() throws {
        config.requestCustomHeaders = ["x-auth": "authKey"]
        let session = DefaultURLSessionFactory(config: config).build()

        let task = session.dataTask(with: exampleURL)

        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["x-auth"], "authKey")
    }

    func testSessionAppendsExtraHeadersToExistingRequestHeaders() throws {
        var request = URLRequest(url: exampleURL)
        request.addValue("requestValue", forHTTPHeaderField: "requestHeader")
        config.requestCustomHeaders = ["x-auth": "authKey"]
        let session = DefaultURLSessionFactory(config: config).build()

        let task = session.dataTask(with: request)

        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["x-auth"], "authKey")
        XCTAssertEqual(task.currentRequest?.allHTTPHeaderFields?["requestHeader"], "requestValue")
    }
}
