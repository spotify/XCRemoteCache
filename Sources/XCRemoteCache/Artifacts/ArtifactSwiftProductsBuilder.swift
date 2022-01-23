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

enum ArtifactSwiftProductsBuilderError: Error {
    /// Thrown when trying to include generated ObjC header to a non-module target
    case populatingObjCHeaderForNonModule
    /// Throws when trying to include non-existing ObjC header
    case populatingNonExistingObjCHeader
    /// Missing generated swiftmodule-related file (e.f. .swiftmodule or .swiftdoc)
    case missingGeneratedModuleFile(path: String)
}

/// A builder to prepare artifact Swift-generated products in a single location, ready to zip into an artifact archive
protocol ArtifactSwiftProductsBuilder {
    /// Location where all files expected to be bundled to the product should be placed
    func buildingArtifactLocation() -> URL
    /// Location where all generated ObjC headers should be placed in order to be bundled into the artifact product
    /// - Returns: location URL to put ObjC headers
    func buildingArtifactObjCHeadersLocation() -> URL
    /// Moves generated ObjC header to the artifact "working" location
    /// - Parameter arch: architecture of the build
    /// - Parameter headerURL: file to include as an ObjC header
    func includeObjCHeaderToTheArtifact(arch: String, headerURL: URL) throws
    /// Moves generated .swift{module|doc} products to the artifact "working" location
    /// - Parameter arch: architecture of the build
    /// - Parameter moduleURL: generated .swift{module|doc|..} file
    func includeModuleDefinitionsToTheArtifact(arch: String, moduleURL: URL) throws
}

/// Default Builder implementation for a Swift module compilation step
/// * all files are stored in #{workingDir}/xccache/produced
/// * all module ObjC headers are stored in
/// # {workingDir}/xccache/produced/include/#{moduleName} (if `moduleName` is defined)
class ArtifactSwiftProductsBuilderImpl: ArtifactSwiftProductsBuilder {

    private let workingDir: URL
    private let moduleName: String?
    private let fileManager: FileManager

    init(workingDir: URL, moduleName: String?, fileManager: FileManager) {
        self.workingDir = workingDir
        self.moduleName = moduleName
        self.fileManager = fileManager
    }

    func buildingArtifactLocation() -> URL {
        return workingDir.appendingPathComponent("xccache").appendingPathComponent("produced")
    }

    func buildingArtifactObjCHeadersLocation() -> URL {
        return buildingArtifactLocation().appendingPathComponent("include")
    }

    func buildingArtifactSwiftModulesLocation() -> URL {
        return buildingArtifactLocation().appendingPathComponent("swiftmodule")
    }

    func includeObjCHeaderToTheArtifact(arch: String, headerURL: URL) throws {
        guard let module = moduleName else {
            throw ArtifactSwiftProductsBuilderError.populatingObjCHeaderForNonModule
        }
        let zipObjCDir = buildingArtifactObjCHeadersLocation()
        // Embed the ObjC header to the include/arch/module_name directory (XCRemoteCache arbitrary format)
        let moduleObjCURL = zipObjCDir.appendingPathComponent(arch).appendingPathComponent(module)

        let objCHeaderFilename = headerURL.lastPathComponent
        let headerArtifactURL = moduleObjCURL.appendingPathComponent(objCHeaderFilename)
        // Product module dir may not exist, even if the `moduleName` is present
        guard fileManager.fileExists(atPath: headerURL.path) else {
            throw ArtifactSwiftProductsBuilderError.populatingNonExistingObjCHeader
        }
        try fileManager.createDirectory(at: moduleObjCURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.spt_forceLinkItem(at: headerURL, to: headerArtifactURL)
    }

    func includeModuleDefinitionsToTheArtifact(arch: String, moduleURL: URL) throws {
        let zipModuleDir = buildingArtifactSwiftModulesLocation()
        // Embed the swiftmodule|doc to the swiftmodule/arch/ directory (XCRemoteCache arbitrary format)
        let artifactModuleURL = zipModuleDir.appendingPathComponent(arch)

        let moduleURLDir = moduleURL.deletingLastPathComponent()
        let swiftModuleFilename = moduleURL.deletingPathExtension().lastPathComponent
        let swiftArtifactModuleBase = moduleURLDir.appendingPathComponent(swiftModuleFilename)
        let filesToInclude: [URL] = try SwiftmoduleFileExtension.SwiftmoduleExtensions.compactMap { ext, type in
            let file = swiftArtifactModuleBase.appendingPathExtension(ext.rawValue)
            guard fileManager.fileExists(atPath: file.path) else {
                if case .required = type {
                    throw ArtifactSwiftProductsBuilderError.missingGeneratedModuleFile(path: file.path)
                } else {
                    return nil
                }
            }
            return file
        }
        // Product module dir may not exist, even if the `moduleName` is present
        try fileManager.createDirectory(at: artifactModuleURL, withIntermediateDirectories: true, attributes: nil)
        for fileToInclude in filesToInclude {
            let filename = fileToInclude.lastPathComponent
            let artifactLocation = artifactModuleURL.appendingPathComponent(filename)
            try fileManager.spt_forceLinkItem(at: fileToInclude, to: artifactLocation)
        }
    }
}
