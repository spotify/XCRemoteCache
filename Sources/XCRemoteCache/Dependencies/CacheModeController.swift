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

enum PhaseCacheModeControllerError: Error {
    /// Trying to disable remote cached for a target that is forced to use the cached artifact
    case cannotUseRemoteCacheForForcedCacheMode
}

/// Controls Remote Cache mode:
protocol CacheModeController {
    /// Enables remote cache for a set of allowed of input files (.swift or .m)
    /// Any compilation for a file that is not on that list should fallback to the compilation mode (if possible)
    /// or stop the build with error
    func enable(allowedInputFiles: [URL], dependencies: [URL]) throws
    /// Disables remote cache and fallbacks to source-compilation
    func disable() throws
    /// Returns true if remote cache mode is enabled
    func isEnabled() throws -> Bool
    /// Returns true if the mode controller should be disabled for that remote commit. That happens when some
    /// xcswift, xccc etc. commands disabled remote cache (e.g. new file was added to the compilation)
    func shouldDisable(for commit: RemoteCommitInfo) -> Bool
}

class PhaseCacheModeController: CacheModeController {
    /// Path to the symbolic link that changes if other xcode is selected with `xcode-select -s`
    static let xcodeSelectLink: URL = URL(fileURLWithPath: "/var/db/xcode_select_link")
    private let mergeCommitFile: URL
    private let modeMarker: URL
    private let forceCached: Bool
    private let dependenciesWriter: DependenciesWriter
    private let dependenciesReader: DependenciesReader
    private let markerWriter: MarkerWriter
    private let llbuildLockFile: URL
    private let fileManager: FileManager

    init(
        tempDir: URL,
        mergeCommitFile: URL,
        phaseDependencyPath: String,
        markerPath: String,
        forceCached: Bool,
        dependenciesWriter: (URL, FileManager) -> DependenciesWriter,
        dependenciesReader: (URL, FileManager) -> DependenciesReader,
        markerWriter: (URL, FileManager) -> MarkerWriter,
        llbuildLockFile: URL,
        fileManager: FileManager
    ) {

        self.mergeCommitFile = mergeCommitFile
        modeMarker = tempDir.appendingPathComponent(markerPath)
        self.fileManager = fileManager
        self.forceCached = forceCached
        let discoveryURL = tempDir.appendingPathComponent(phaseDependencyPath)
        self.dependenciesWriter = dependenciesWriter(discoveryURL, fileManager)
        self.dependenciesReader = dependenciesReader(discoveryURL, fileManager)
        self.llbuildLockFile = llbuildLockFile
        self.markerWriter = markerWriter(modeMarker, fileManager)
    }

    func enable(allowedInputFiles: [URL], dependencies: [URL]) throws {
        try cleanupLlBuildLock()
        // marker file contains filepaths that contribute to the build products
        // and should invalidate all other target steps (swiftc,libtool etc.)
        let targetSensitiveFiles = dependencies + [modeMarker, Self.xcodeSelectLink]
        try markerWriter.enable(dependencies: targetSensitiveFiles)
        // All rc-phases (prebuid & postbuild) should be reenabled when new remote
        // merge commit or other Xcode is used
        let allDependencies = dependencies + [mergeCommitFile, Self.xcodeSelectLink]
        try dependenciesWriter.writeGeneric(dependencies: allDependencies)
    }

    func disable() throws {
        try cleanupLlBuildLock()
        guard !forceCached else {
            throw PhaseCacheModeControllerError.cannotUseRemoteCacheForForcedCacheMode
        }
        try markerWriter.disable()
        // Do not try to use remote cache anymore unless new remote cache merge commit or xcode is in use
        try dependenciesWriter.writeGeneric(dependencies: [mergeCommitFile, Self.xcodeSelectLink])
    }

    func isEnabled() throws -> Bool {
        return fileManager.fileExists(atPath: modeMarker.path)
    }

    /// Returns true if the phase dependency file contains a ["skipForSha": "some_sha"] entry and
    /// "some_sha" is equal to the `commit` argument
    func shouldDisable(for commit: RemoteCommitInfo) -> Bool {
        guard case .available(let commitValue) = commit else {
            return true
        }
        do {
            let rawDependencies = try dependenciesReader.readFilesAndDependencies()
            if let commitToSkip = rawDependencies[FileDependenciesWriter.skipForShaKey] {
                return commitToSkip.contains(commitValue)
            }
        } catch {
            // Gracefully don't disable a cache
            // That may happen if building a target for the first time
            debugLog("Couldn't verify if should disable RC for \(commitValue).")
        }
        return false
    }

    private func cleanupLlBuildLock() throws {
        if fileManager.fileExists(atPath: llbuildLockFile.path) {
            do {
                try fileManager.removeItem(at: llbuildLockFile)
            } catch {
                printWarning("Removing llbuild lock at \(llbuildLockFile.path) failed. Error: \(error)")
            }
        }
    }
}
