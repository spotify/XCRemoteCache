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

/// Creates response in a json, human friendly format
class XCJSONEncoder: XCRemoteCacheEncoder {
    private let encoder: JSONEncoder
    init() {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = .prettyPrinted
        self.encoder = encoder
    }

    func encode<T>(_ value: T) throws -> String where T: Encodable {
        let data = try encoder.encode(value)
        guard let stringRepresentation = String(data: data, encoding: .utf8) else {
            throw XCRemoteCacheEncoderError.cannotRepresentOutput
        }
        return stringRepresentation
    }
}
