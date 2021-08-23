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

/// Decides which location location should be considered in the fingerprint computation
/// Meant to replaces machine-specific products (like .swiftmodule) with its source-aware fingerprint representation
protocol FingerprintOverrideManager {
    /// File extensions that should be replced by an override
    var overridingFileExtensions: [String] { get }
    /// Returns a file that should be considered in the fingerprint generation
    func getFingerprintFile(_ url: Dependency) -> Dependency
}

/// Manager that rewrites dependencies to the fingerprint override
/// if the override file exists on a disk
public class FingerprintOverrideManagerImpl: FingerprintOverrideManager {
    private let overrideExtension: String
    private let fileManager: FileManager
    let overridingFileExtensions: [String]

    /// Initializer
    /// @param overrideExtension: all extensions that require fingerprint override
    /// @param fingerprintOverrideExtension: file extension of the fingerprint override
    /// @param fileManager: fileManager instance to check file existance
    public init(
        overridingFileExtensions: [String],
        fingerprintOverrideExtension: String,
        fileManager: FileManager
    ) {
        self.overridingFileExtensions = overridingFileExtensions
        overrideExtension = fingerprintOverrideExtension
        self.fileManager = fileManager
    }

    public func getFingerprintFile(_ dependency: Dependency) -> Dependency {
        // Require overrides only it already exists on a disk
        // If the dependency was not generated locally (e.g. distributed
        // as a binary) and misses ".{{overrideExtension}}",
        // the fingerprint of a raw file can be safely used
        let fingerprintOverrideURL = dependency.url.appendingPathExtension(overrideExtension)
        let isFileExistOnDisk = fileManager.fileExists(atPath: fingerprintOverrideURL.path)
        if overridingFileExtensions.contains(dependency.url.pathExtension) && isFileExistOnDisk {
            return Dependency(url: fingerprintOverrideURL, type: .fingerprint)
        }
        return dependency
    }
}
