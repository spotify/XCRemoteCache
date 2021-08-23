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

struct AWSV4Signature {

    let secretKey: String
    let accessKey: String
    let region: String
    let service: String
    let date: Date


    func addSignatureHeaderTo(request: inout URLRequest) {

        request.setValue(request.url?.host, forHTTPHeaderField: "host")
        request.setValue(StringToSign.ISO8601BasicFormatter.string(from: date), forHTTPHeaderField: "x-amz-date")
        request.setValue((request.httpBody ?? Data()).sha256(), forHTTPHeaderField: "x-amz-content-sha256")

        let canonicalRequest = CanonicalRequest(request: request)
        let stringToSign = StringToSign(region: region, service: service, canonicalRequestHash: canonicalRequest.hash, date: date)
        let awsV4SigningKey = AWSV4SigningKey(secretAccessKey: secretKey, region: region, service: service, date: date)
        let signature = HMAC.calcHMAC(keyArray: awsV4SigningKey.value, value: stringToSign.value).map { String(format: "%02hhx", $0) }.joined()

        let authValue =
            "AWS4-HMAC-SHA256 " +
                "Credential=\(accessKey)/\(stringToSign.credentialScope), " +
                "SignedHeaders=\(canonicalRequest.signedHeaders(headers: request.allHTTPHeaderFields)), " +
                "Signature=\(signature)"

        request.setValue(authValue, forHTTPHeaderField: "Authorization")
    }
}
