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


enum ThinningCreatorPluginError: Error {
    /// Consistency error: a target with enabled XCRemoteCache doesn't contain a single artifact product. Make sure
    /// the DerivedData directory is cleared before a build
    case noSingleTargetArtifactsGenerated(rootDir: URL)
}

/// Plugin that includes fileKeys of all cached targets in a target meta
/// If scans all directories in the DerivedData to find targets that recently prepared and uploaded artifacts to the
/// remote cache storage. It is important to enabled that plugin only for a target that is build as a last step of the
/// building process (so it can find all relevant build products in DerivedData) for each "configuration+arch" pair
/// Warning! This plugin assumes that producer's DerivedData are always cleaned before a build
class ThinningCreatorPlugin: ArtifactCreatorPlugin {
    private let targetTempDir: URL
    private let modeMarkerPath: String
    private let dirScanner: DirScanner

    /// Default Initializer
    /// - Parameter targetTempDir: Location of current target-specific temp dir (TARGET_TEMP_DIR)
    /// - Parameter modeMarkerPath: path of maker file that informs if a given target can reuse remote artifacts.
    /// - Parameter dirScanner: scanner to access disk and read files and directories hierarchy
    init(targetTempDir: URL, modeMarkerPath: String, dirScanner: DirScanner) {
        self.targetTempDir = targetTempDir
        self.modeMarkerPath = modeMarkerPath
        self.dirScanner = dirScanner
    }

    let customPathsRemapper: DependenciesRemapper? = nil

    func extraMetaKeys(_ meta: MainArtifactMeta) throws -> [String: String] {
        // Navigate to the root targetTempDir of all build products (for a specific Configuration+architecture)
        let allTargetsTempDirRoot = targetTempDir.deletingLastPathComponent()

        // iterate all temp directories to find generated and uploaded artifacts. We assume that the DerivedData
        // was emptied before a build so all generated .zip files correspond to a current build
        let allURLs = try dirScanner.items(at: allTargetsTempDirRoot)
        struct TargetTuple {
            let targetName: String
            let fileKey: String
        }
        let uploadedTargetArtifacts = try allURLs.compactMap { tempDir -> TargetTuple? in
            let potentialArtifacts = try findTargetPackageZip(tempDir: tempDir)
            guard let allArtifacts = potentialArtifacts, !allArtifacts.isEmpty else {
                // there is no generated *.zip file, so given target didn't create an artifact - it could be
                // just a helper target (like the target we integrate this plugin with)
                return nil
            }
            // Find {{fileKey}} based on the .zip file basename
            guard allArtifacts.count == 1 else {
                throw ThinningCreatorPluginError.noSingleTargetArtifactsGenerated(
                    rootDir: tempDir
                )
            }
            let fileKey = allArtifacts[0].deletingPathExtension().lastPathComponent
            // Taking target name from tempDir, which has a structures "*.build"
            let targetName = tempDir.deletingPathExtension().lastPathComponent
            return TargetTuple(targetName: targetName, fileKey: fileKey)
        }
        // Build a dictionary that will be appended to the meta with a format:
        // {
        //   "thinning_TargetName1": "ab2331a",
        //   "thinning_TargetName2": "23a2b1b"
        // }
        let extraKeysTuples = uploadedTargetArtifacts
            .map { ("\(ThinningPlugin.fileKeyPrefix)\($0.targetName)", $0.fileKey) }
        return Dictionary(uniqueKeysWithValues: extraKeysTuples)
    }

    private func findTargetPackageZip(tempDir: URL) throws -> [URL]? {
        // Producer mode:
        // All targets that uploaded their artifacts, have it placed in the
        // `$(TARGET_TEMP_DIR)/xccache/produced/{{fileKey}}.zip` location. Find all targets that have such a file
        // ProducerFast mode:
        // If a target reused already existing artifact, it still has `$(TARGET_TEMP_DIR)/rc.enabled` marker file
        // and the reused zip is placed in:
        // `$(TARGET_TEMP_DIR)/xccache/{{fileKey}}.zip` location.

        let targetEnabledMarker = tempDir.appendingPathComponent(modeMarkerPath)
        let targetReusedArtifactRootDir = tempDir.appendingPathComponent("xccache")
        let targetGeneratedArtifactRootDir = tempDir
            .appendingPathComponent("xccache")
            .appendingPathComponent("produced")

        let pathToDirWithZipArtifacts: URL
        // try the `.producerFast` scenario first (the artifact was not locally
        // generated but just reused from the remote cache)
        if try dirScanner.itemType(atPath: targetEnabledMarker.path) == ItemType.file {
            pathToDirWithZipArtifacts = targetReusedArtifactRootDir
        } else {
            // cover a case when a target was build locally and an artifact
            // has just been created (locally)
            guard try dirScanner.itemType(atPath: targetGeneratedArtifactRootDir.path) == ItemType.dir else {
                // given target didn't generate any artifacts (e.g. it is never cached with XCRemoteCache)
                return nil
            }
            pathToDirWithZipArtifacts = targetGeneratedArtifactRootDir
        }

        let allFilesProduced = try dirScanner.items(at: pathToDirWithZipArtifacts)
        let allArtifacts = allFilesProduced.filter { $0.pathExtension == "zip" }
        return allArtifacts
    }

    func artifactToUpload(main: MainArtifactMeta) throws -> [Artifact] {
        return []
    }
}
