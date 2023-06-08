// Copyright (c) 2023 Spotify AB.
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

enum ACToolResult: Equatable {
    /// the generated actool interfaces matches the one observed on a producer side
    case cacheHit(dependencies: [URL])
    /// the generated interface is different - leads to a cache miss
    case cacheMiss
}

class ACTool {
    private let markerReader: ListReader
    private let markerWriter: MarkerWriter
    private let metaReader: MetaReader
    private let fingerprintAccumulator: FingerprintAccumulator
    private let metaPathProvider: MetaPathProvider

    init(
        markerReader: ListReader,
        markerWriter: MarkerWriter,
        metaReader: MetaReader,
        fingerprintAccumulator: FingerprintAccumulator,
        metaPathProvider: MetaPathProvider
    ) {
        self.markerReader = markerReader
        self.markerWriter = markerWriter
        self.metaReader = metaReader
        self.fingerprintAccumulator = fingerprintAccumulator
        self.metaPathProvider = metaPathProvider
    }

    func run() throws -> ACToolResult {
        // 1. do nothing if the RC is disabled
        guard markerReader.canRead() else {
            return .cacheMiss
        }
        let dependencies = try markerReader.listFilesURLs()

        // 2. Read meta's sources files & fingerprint
        let metaPath = try metaPathProvider.getMetaPath()
        let meta = try metaReader.read(localFile: metaPath)
        // 3. Compare local vs meta's fingerprint
        let localFingerprint = try computeFingerprints(meta.assetsSources)
        // 4. Disable RC if the is fingerprint doesn't match
        return (localFingerprint == meta.assetsSourcesFingerprint ? .cacheHit(dependencies: dependencies) : .cacheMiss)
    }

    private func computeFingerprints(_ paths: [String]) throws -> RawFingerprint {
        // TODO:
        // 1. transform to URL
        // 2. build (in the same order the fingerprint)
        fingerprintAccumulator.reset()
        for path in paths {
            let file = URL(fileURLWithPath: path)
            do {
                try fingerprintAccumulator.append(file)
            } catch FingerprintAccumulatorError.missingFile(let content) {
                printWarning("File at \(content.path) was not found on disc. Calculating fingerprint without it.")
            }
        }
        return try fingerprintAccumulator.generate()
    }
}
