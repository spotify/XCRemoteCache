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
import Zip

enum ArtifactOrganizerError: Error {
    case invalidLocation(URL)
}

enum ArtifactOrganizerLocationPreparationResult: Equatable {
    /// Artifact already exists at the artifactDir
    case artifactExists(artifactDir: URL)
    /// Ready to download the artifact into artifact location
    case preparedForArtifact(artifact: URL)
}

/// Prepares existing .zip artifact for the local operations
protocol ArtifactOrganizer {
    /// Prepares the location for the artifact unzipping
    /// - Parameter fileKey: artifact fileKey that corresponds to the zip filename on the remote cache server
    func prepareArtifactLocationFor(fileKey: String) throws -> ArtifactOrganizerLocationPreparationResult
    /// Unzips the zip artifact at the URL
    func prepare(artifact: URL) throws -> URL
    /// Activates the artifact - to all other xc* applications use it (links the directory to the "active" location)
    func activate(extractedArtifact: URL) throws
    /// Returns local location of the artifact to use in cached scenario (aka active artifact)
    func getActiveArtifactLocation() -> URL
    /// Returns a fileKey of the current active artifact
    func getActiveArtifactFilekey() throws -> String
}

class ZipArtifactOrganizer: ArtifactOrganizer {
    static let activeArtifactLocation = "active"

    private let cacheDir: URL
    // all processors that should "prepare" the unzipped raw artifact
    private let artifactProcessors: [ArtifactProcessor]
    private let fileManager: FileManager

    init(targetTempDir: URL, artifactProcessors: [ArtifactProcessor], fileManager: FileManager) {
        cacheDir = targetTempDir.appendingPathComponent("xccache")
        self.artifactProcessors = artifactProcessors
        self.fileManager = fileManager
    }

    private func getArtifactLocation(for fileKey: String) -> URL {
        return cacheDir.appendingPathComponent(fileKey)
    }

    func getActiveArtifactLocation() -> URL {
        return cacheDir.appendingPathComponent(Self.self.activeArtifactLocation)
    }

    func getActiveArtifactFilekey() throws -> String {
        let activeLocation = getActiveArtifactLocation()
        // Context specific fingerprint is used as a name of an active directory symlink. That ensures that
        // aritfacts do not mix up with each other but also gives a chance here to quickly get a fingerprint string
        let localArtifactLocation = try fileManager.spt_followSymbolicLink(activeLocation)
        return localArtifactLocation.lastPathComponent
    }

    func prepareArtifactLocationFor(fileKey: String) throws -> ArtifactOrganizerLocationPreparationResult {
        let artifactDirURL = getArtifactLocation(for: fileKey)
        let artifactPackageURL = artifactDirURL.appendingPathExtension("zip")

        if fileManager.fileExists(atPath: artifactDirURL.path) {
            return .artifactExists(artifactDir: artifactDirURL)
        }
        try createParentLocation(for: artifactPackageURL)
        return .preparedForArtifact(artifact: artifactPackageURL)
    }


    func prepare(artifact: URL) throws -> URL {
        let destinationURL = artifact.deletingPathExtension()
        guard fileManager.fileExists(atPath: destinationURL.path) == false else {
            infoLog("Skipping artifact, already existing at \(destinationURL)")
            try runArtifactProcessors(artifactLocation: destinationURL)
            return destinationURL
        }
        // Unzipping to a temp file first to never leave the uncompleted zip in the final location
        // when the command was interrupted (internal crash or `kill -9` signal)
        let tempDestination = destinationURL.appendingPathExtension("tmp")
        try Zip.unzipFile(artifact, destination: tempDestination, overwrite: true, password: nil)

        try fileManager.moveItem(at: tempDestination, to: destinationURL)
        try runArtifactProcessors(artifactLocation: destinationURL)
        return destinationURL
    }

    /// Iterates all processor when an artifact has been just downloaded or reused from already downloaded
    /// and previously processed location
    private func runArtifactProcessors(artifactLocation: URL) throws {
        try artifactProcessors.forEach { processor in
            try processor.process(rawArtifact: artifactLocation)
        }
    }

    func activate(extractedArtifact: URL) throws {
        let activeLocationURL = getActiveArtifactLocation()
        try fileManager.spt_forceSymbolicLink(at: activeLocationURL, withDestinationURL: extractedArtifact)
    }

    private func createParentLocation(for file: URL) throws {
        let directoryURL = file.deletingLastPathComponent()
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDir) {
            guard isDir.boolValue else {
                errorLog("Invalid Artifact parent location at: \(directoryURL.description)")
                throw ArtifactOrganizerError.invalidLocation(directoryURL)
            }
        } else {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
    }
}
