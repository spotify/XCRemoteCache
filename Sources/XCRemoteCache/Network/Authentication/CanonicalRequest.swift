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

struct CanonicalRequest {

    let request: URLRequest

    var value: String? {
        guard let httpMethod = request.httpMethod,
            let url = request.url,
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else {
                return nil
        }
        let path: String
        if url.path.isEmpty {
            path = "/"
        } else {
            path = url.path
        }
        return
            "\(httpMethod)\n" +
                "\(path)\n" +
                "\(canonicalQueryString(urlComponents: urlComponents))\n" +
                "\(canonicalHeaders(headers: request.allHTTPHeaderFields))\n\n" +
                "\(signedHeaders(headers: request.allHTTPHeaderFields))\n" +
                "\(request.httpBody?.sha256() ?? Data().sha256())"
    }

    var hash: String {
        value?.data(using: .utf8)!.sha256() ?? ""
    }

    private func canonicalQueryString(urlComponents: URLComponents) -> String {
        return urlComponents.queryItems?.map { item -> (String, String) in
            (item.name, item.value ?? "")
        }.sorted(by: { first, second in
            first.0 < second.0
        }).reduce(into: "") { result, value in
            if let resultInitialized = result, !resultInitialized.isEmpty {
                result = "\(resultInitialized)&"
            }
            result = "\(result ?? "")\(value.0)=\(value.1)"
        } ?? ""
    }

    private func canonicalHeaders(headers: [String: String]?) -> String {
        return headers?.keys.map { key in
            (
                key.lowercased().trimmingCharacters(in: .whitespaces),
                headers?[key]?.trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "[\\s]{2,}", with: " ", options: [.regularExpression]) ?? ""
            )
        }.sorted(by: { first, second in
            first.0 < second.0
        }).reduce(into: "") { result, value in
            if let resultInitialized = result, !resultInitialized.isEmpty {
                result = "\(resultInitialized)\n"
            }
            result = "\(result ?? "")\(value.0):\(value.1)"
        } ?? ""
    }

    func signedHeaders(headers: [String: String]?) -> String {
        return headers?.keys.map { key in
            key.lowercased().trimmingCharacters(in: .whitespaces)
        }.sorted(by: { first, second in
            first < second
        }).reduce(into: "") { result, value in
            if let resultInitialized = result, !resultInitialized.isEmpty {
                result = "\(resultInitialized);"
            }
            result = "\(result ?? "")\(value)"
        } ?? ""
    }
}
