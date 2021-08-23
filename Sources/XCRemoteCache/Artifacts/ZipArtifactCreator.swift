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

class ZipArtifactCreator {
    /// Location where zip file should be generated
    private let workingDir: URL
    private let fileManager: FileManager
    private let metaEncoder = JSONEncoder()

    init(workingDir: URL, fileManager: FileManager) {
        self.workingDir = workingDir
        self.fileManager = fileManager
    }

    func createArtifact<T: Meta>(zipContent: [URL], artifactKey: String, meta: T) throws -> Artifact {
        let zipURL = workingDir.appendingPathComponent("\(artifactKey).zip")
        try fileManager.createDirectory(at: workingDir, withIntermediateDirectories: true, attributes: nil)
        // Include meta json to the artifact
        let metaURL = try dumpMeta(meta)
        let zipPaths = zipContent + [metaURL]

        try Zip.zipFiles(paths: zipPaths, zipFilePath: zipURL, password: nil, progress: nil)
        return Artifact(id: artifactKey, package: zipURL, meta: metaURL)
    }

    // Save meta to a local file
    private func dumpMeta<T: Meta>(_ meta: T) throws -> URL {
        let metaURL = workingDir.appendingPathComponent(meta.fileKey).appendingPathExtension("json")
        let metaData = try metaEncoder.encode(meta)
        try fileManager.spt_writeToFile(atPath: metaURL.path, contents: metaData)
        return metaURL
    }
}
