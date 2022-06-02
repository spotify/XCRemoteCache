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

class FingerprintAccumulatorFake: FingerprintAccumulator {
    private var appendedStrings: [String] = []
    func append(_ content: String) throws {
        appendedStrings.append(content)
    }

    func reset() {
        appendedStrings = []
    }

    func append(_ file: URL) throws {
        appendedStrings.append("FILE{\(file.path)}")
    }

    private(set) var generateCallCount = 0
    func generate() throws -> RawFingerprint {
        defer {
            generateCallCount += 1
        }
        return appendedStrings.joined(separator: ",")
    }
}
