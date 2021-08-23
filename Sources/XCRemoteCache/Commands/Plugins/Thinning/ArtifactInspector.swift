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

enum ArtifactInspectorError: Error {
    /// The unzipped artifact is malformed. Is misses *.swiftmodule file in "swiftmodule/{{arch}}" directory
    case missingSwiftmoduleFileInArtifact(artifact: URL)
}

// Inspects the unzipped artifact
protocol ArtifactInspector {
    /// Enumerates all files in an artifact and finds out which should be moved to the builtProductsDir
    /// - Parameter artifact: location of the unzipped artifact
    /// - Returns: all files/dirs to move to builtProductsDir
    func findBinaryProducts(fromArtifact artifact: URL) throws -> [URL]
    /// Inspects unzipped artifact file structure to recognize the name of a module name
    func recognizeModuleName(fromArtifact artifact: URL, arch: String) throws -> String?
}

class DefaultArtifactInspector: ArtifactInspector {
    private let dirAccessor: DirAccessor
    /// Name of a directory in an artifact that stores swiftmodules files
    private static let ArtifactSwiftmoduleDir = "swiftmodule"
    /// Swiftmodule file extension in an artifact
    private static let SwiftmoduleFileExtension = "swiftmodule"
    /// Extensions of files that should be considered as binaries
    // TODO: Supporting only libraries for now. Consider other formats like frameworks or dsyms
    private static let BinaryProductsExtensions = ["a"]

    init(dirAccessor: DirAccessor) {
        self.dirAccessor = dirAccessor
    }

    func findBinaryProducts(fromArtifact artifact: URL) throws -> [URL] {
        let artifactItems = try dirAccessor.items(at: artifact)
        return artifactItems.filter { Self.BinaryProductsExtensions.contains($0.pathExtension) }
    }

    func recognizeModuleName(fromArtifact artifact: URL, arch: String) throws -> String? {
        let swiftmodulesDir = artifact
            .appendingPathComponent(Self.ArtifactSwiftmoduleDir)
            .appendingPathComponent(arch)
        guard case .dir = try dirAccessor.itemType(atPath: swiftmodulesDir.path) else {
            // This target doesn't contain any swiftmodule (e.g. ObjC target)
            return nil
        }
        // All files have basename of a modulename
        let moduleFiles = try dirAccessor.items(at: swiftmodulesDir)
        // Find a first *.swiftmodule file's basename - the "swiftmodule/{{arch}}" directory contains
        // {{moduleName}}.swiftc{module|doc} files
        let swiftmoduleFile = moduleFiles.first(where: { $0.pathExtension == Self.SwiftmoduleFileExtension })
        guard swiftmoduleFile != nil else {
            throw ArtifactInspectorError.missingSwiftmoduleFileInArtifact(artifact: artifact)
        }
        return swiftmoduleFile.map { $0.deletingPathExtension().lastPathComponent }
    }
}
