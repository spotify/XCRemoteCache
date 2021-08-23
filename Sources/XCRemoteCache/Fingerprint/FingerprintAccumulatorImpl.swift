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

/// Generates content fingerprint from input Strings and local file contents
public class FingerprintAccumulatorImpl: FingerprintAccumulator {
    private let algorithm: HashingAlgorithm
    private let fileManager: FileManager

    init(algorithm: HashingAlgorithm, fileManager: FileManager) {
        self.algorithm = algorithm
        self.fileManager = fileManager
    }

    public func reset() {
        algorithm.reset()
    }

    public func append(_ content: String) {
        algorithm.add(content)
    }

    public func append(_ content: URL) throws {
        // TODO: consider reading file in chunks if content file is huge
        guard let data = fileManager.contents(atPath: content.path) else {
            throw FingerprintAccumulatorError.missingFile(content)
        }
        algorithm.add(data)
    }

    public func generate() throws -> RawFingerprint {
        return algorithm.finalizeString()
    }
}
