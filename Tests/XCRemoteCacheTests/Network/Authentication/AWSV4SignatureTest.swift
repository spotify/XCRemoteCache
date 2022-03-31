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

class AWSV4SignatureTest: XCTestCase {

    var request: URLRequest!

    // Example from
    // https://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html
    override func setUp() {
        super.setUp()
        let url = URL(string: "https://iam.amazonaws.com/?Action=ListUsers&Version=2010-05-08")!
        request = URLRequest(url: url)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let key = "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
        let accessKey = "AKIDEXAMPLE"
        let securityToken = "IQoJb3JpZ2luX2VjENv//////////wEaCXVzLWVhc3Q+bsHwqnovXtl/1JVe61XHMnAw3AIXwOAOxqMvhw=="

        AWSV4Signature(
            secretKey: key,
            accessKey: accessKey,
            securityToken: securityToken,
            region: "us-east-1",
            service: "iam",
            date: Date(timeIntervalSince1970: 1_440_938_160)
        )
        .addSignatureHeaderTo(request: &request)
    }

    func testAuthHeaderContainsCorrectSignature() throws {
        XCTAssertEqual(
            "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request, " +
                "SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date;x-amz-security-token, " +
                "Signature=d26ab974bba1b248f041ea1120064e1fa672d6f06cac2cff42b38acea87b76e5",
            request.allHTTPHeaderFields?["Authorization"]
        )
    }
}
