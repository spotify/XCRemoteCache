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

/// Generates (producer) or moves (consumer) dSYM directory to include
protocol DSYMOrganizer {
    /// Returns location of the existing dSYM directory, nil when dSYM is not required to share in the artifact
    /// In the 'producer' mode, for a non-static library that haven't already generated dSYM (Product is just "DWARF"),
    /// generates dSYM anyway to share debugging symbols with the artifact
    ///
    /// - Returns: Path to the available dSYM package (generated or already existing)
    func relevantDSYMLocation() throws -> URL?
    /// Moves dSYM to the final destination, if one exists in the cached artifact
    /// - Parameter artifactPath: location of the unzipped artifact from cache
    func syncDSYM(artifactPath: URL) throws
    /// Removes all leftovers from previous dSYM synchronizations
    func cleanup() throws
}


class DynamicDSYMOrganizer: DSYMOrganizer {
    private let productURL: URL
    private let dSYMPath: URL
    private let machOType: MachOType
    private let wasDsymGenerated: Bool
    private let fileManager: FileManager
    private let shellCall: ShellCallFunction

    init(
        productURL: URL,
        machOType: MachOType,
        dSYMPath: URL,
        wasDsymGenerated: Bool,
        fileManager: FileManager,
        shellCall: @escaping ShellCallFunction
    ) {
        self.productURL = productURL
        self.machOType = machOType
        self.dSYMPath = dSYMPath
        self.wasDsymGenerated = wasDsymGenerated
        self.fileManager = fileManager
        self.shellCall = shellCall
    }

    func relevantDSYMLocation() throws -> URL? {
        guard [.dynamicLib, .executable, .bundle].contains(machOType) else {
            return nil
        }
        guard wasDsymGenerated == false else {
            // dSYM has already been regerated
            return dSYMPath
        }
        try shellCall("dsymutil", [productURL.path, "-o", dSYMPath.path], nil, ProcessInfo.processInfo.environment)
        return dSYMPath
    }


    func syncDSYM(artifactPath: URL) throws {
        let dSYMFileName = dSYMPath.lastPathComponent
        let cachedDSYMPath = artifactPath.appendingPathComponent(dSYMFileName)
        if fileManager.fileExists(atPath: cachedDSYMPath.path) {
            try fileManager.spt_forceLinkItem(at: cachedDSYMPath, to: dSYMPath)
        }
    }

    func cleanup() throws {
        if !wasDsymGenerated && fileManager.fileExists(atPath: dSYMPath.path) {
            try fileManager.removeItem(at: dSYMPath)
        }
    }
}
