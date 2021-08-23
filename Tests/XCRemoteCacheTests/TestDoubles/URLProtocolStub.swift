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

class URLProtocolStub: URLProtocol {
    enum Response {
        case success(URLResponse, Data)
        case timeout
    }

    static var responses: [URL: Response] = [:]
    static var requests: [URLRequest] = []
    static let timeoutError = NSError(domain: "URLProtocolStubError", code: NSURLErrorTimedOut, userInfo: nil)

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        if let url = request.url, let response = Self.responses[url] {
            switch response {
            case .success(let urlResponse, let data):
                client?.urlProtocol(self, didReceive: urlResponse, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
            case .timeout:
                client?.urlProtocol(self, didFailWithError: Self.timeoutError)
            }
        } else {
            client?.urlProtocol(self, didFailWithError: "Not expected URL")
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
