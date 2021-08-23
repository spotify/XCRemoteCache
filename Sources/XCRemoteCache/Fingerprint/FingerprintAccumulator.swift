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

public typealias RawFingerprint = String
public typealias ContextSpecificFingerprint = String

public struct Fingerprint {
    /// Raw fingerprint
    let raw: RawFingerprint
    /// Raw fingerprint interleaved with the env context
    let contextSpecific: ContextSpecificFingerprint
}

enum FingerprintAccumulatorError: Error {
    case missingFile(URL)
}

/// Fingerprint generator that produces a raw String
public protocol FingerprintAccumulator {
    func reset()
    func append(_ content: String) throws
    func append(_ file: URL) throws
    func generate() throws -> RawFingerprint
}

/// Generator of the fingerprint that includes a context/environment aware fingerprint
public protocol ContextAwareFingerprintAccumulator: FingerprintAccumulator {
    func generate() throws -> Fingerprint
}
