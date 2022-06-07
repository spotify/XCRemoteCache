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

enum FingerprintSyncerError: Error {
    case missingResourceValue(URL)
    case invalidFingerprint
}

/// Syncs custom fingerprint overrides
protocol FingerprintSyncer {
    /// Sets a fingerprint override for all files placed directly in a source location
    func decorate(sourceDir: URL, fingerprint: String) throws
    /// Deletes fingerprint overrides in the dir (if already created)
    func delete(sourceDir: URL) throws
    /// Sets a fingerprint override for a singe file placed
    func decorate(file: URL, fingerprint: String) throws
    /// Deletes fingerprint override for a file  (if already created)
    func delete(file: URL) throws
}

class FileFingerprintSyncer: FingerprintSyncer {
    /// Extension of the file that keeps fingerprint override
    private let fingerprintExtension: String
    private let dirAccessor: DirAccessor
    /// A list of all extensions that should be decorated with an override
    private let extensions: [String]

    init(
        fingerprintOverrideExtension: String,
        dirAccessor: DirAccessor,
        extensions: [String]
    ) {
        self.dirAccessor = dirAccessor
        fingerprintExtension = fingerprintOverrideExtension
        self.extensions = extensions
    }

    func decorate(sourceDir: URL, fingerprint: String) throws {
        guard let fingerprintData = fingerprint.data(using: .utf8) else {
            throw FingerprintSyncerError.invalidFingerprint
        }
        guard case .dir = try dirAccessor.itemType(atPath: sourceDir.path) else {
            // no directory to decorate (no module was generated)
            return
        }
        let allURLs = try dirAccessor.items(at: sourceDir)
        // recursive search is not required as all files are located in a root dir
        for file in allURLs {
            if extensions.contains(file.pathExtension) {
                let fingerprintFile = file.appendingPathExtension(fingerprintExtension)
                try dirAccessor.write(toPath: fingerprintFile.path, contents: fingerprintData)
            }
        }
    }

    func delete(sourceDir: URL) throws {
        guard case .dir = try dirAccessor.itemType(atPath: sourceDir.path) else {
            // no directory to decorate (no module was generated)
            return
        }
        let allURLs = try dirAccessor.items(at: sourceDir)
        // recursive search is not required as all files are located in a root dir
        for file in allURLs where file.pathExtension == fingerprintExtension {
            try dirAccessor.removeItem(atPath: file.path)
        }
    }

    func decorate(file: URL, fingerprint: String) throws {
        guard let fingerprintData = fingerprint.data(using: .utf8) else {
            throw FingerprintSyncerError.invalidFingerprint
        }
        let fingerprintFile = file.appendingPathExtension(fingerprintExtension)
        try dirAccessor.write(toPath: fingerprintFile.path, contents: fingerprintData)
    }

    func delete(file: URL) throws {
        guard case .file = try dirAccessor.itemType(atPath: file.path) else {
            // no file to decorate (no module was generated)
            return
        }
        let overrideURL = file.appendingPathExtension(fingerprintExtension)
        try dirAccessor.removeItem(atPath: overrideURL.path)
    }
}
