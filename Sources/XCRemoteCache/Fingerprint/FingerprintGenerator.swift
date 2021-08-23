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

/// Generator of the environment-aware fingerprint
public class FingerprintGenerator: ContextAwareFingerprintAccumulator {
    private let simpleAccumulator: FingerprintAccumulator
    private let envFingerprint: RawFingerprint
    private let algorithm: HashingAlgorithm


    init(envFingerprint: RawFingerprint, _ accumulator: FingerprintAccumulator, algorithm: HashingAlgorithm) {
        self.envFingerprint = envFingerprint
        simpleAccumulator = accumulator
        self.algorithm = algorithm
    }

    public func generate() throws -> Fingerprint {
        let raw: RawFingerprint = try generate()
        let contextSpecific = generateContextSpecific(raw: raw)
        return Fingerprint(raw: raw, contextSpecific: contextSpecific)
    }

    public func append(_ content: String) throws {
        try simpleAccumulator.append(content)
    }

    public func append(_ file: URL) throws {
        try simpleAccumulator.append(file)
    }

    public func reset() {
        simpleAccumulator.reset()
    }

    public func generate() throws -> RawFingerprint {
        return try simpleAccumulator.generate()
    }

    private func generateContextSpecific(raw: String) -> String {
        algorithm.reset()
        algorithm.add(raw)
        algorithm.add(envFingerprint)
        return algorithm.finalizeString()
    }
}
