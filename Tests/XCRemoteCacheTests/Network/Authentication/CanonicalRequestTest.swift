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

import Foundation
@testable import XCRemoteCache
import XCTest

class CanonicalRequestTest: XCTestCase {
    var request = URLRequest(url:
        URL(string: "https://region.amazonaws.com/bucket/file?param=value&hej=hej&abd=cde&test=-_.~")!)


    override func setUp() {
        super.setUp()
        request.setValue("X-Header1Value", forHTTPHeaderField: "X-Header1Key")
        request.setValue("A-Header2Value", forHTTPHeaderField: "A-Header2Key")
        request.setValue("  B-Header3Value  ", forHTTPHeaderField: "    B-Header3Key ")
        request.setValue("C Header  4   Value", forHTTPHeaderField: "C-Header4Key")

        request.httpMethod = "GET"
    }

    func testCanonicalRequest() {
        let canonicalRequest = CanonicalRequest(
            request: request
        )
        XCTAssertEqual(
            canonicalRequest.value,
            "GET\n" +
                "/bucket/file\n" +
                "abd=cde&hej=hej&param=value&test=-_.~\n" +
                "a-header2key:A-Header2Value\n" +
                "b-header3key:B-Header3Value\n" +
                "c-header4key:C Header 4 Value\n" +
                "x-header1key:X-Header1Value\n\n" +
                "a-header2key;b-header3key;c-header4key;x-header1key\n" +
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
    }

    func testCanonicalRequestHash() {
        let canonicalRequest = CanonicalRequest(
            request: request
        )
        XCTAssertEqual(
            canonicalRequest.hash,
            "e86853b3bf2ae1c63474413019575d73358f3c77f222ea44ce59789b6ac824d6"
        )
    }
}
