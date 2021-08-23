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

enum MirroredLinkingSwiftcProductsGeneratorError: Error {
    /// When the generation source list misses a path to the main "swiftmodule" file
    case missingMainSwiftmoduleFileToGenerateFrom
}

/// Products generator that finds swift products destination based on the artifact dir structure. It uses
/// `LinkingSwiftcProductsGenerator` under the hood
///
/// Useful for cases where destination locations are not provided explicitly (e.g. in a thin projects)
class MirroredLinkingSwiftcProductsGenerator: SwiftcProductsGenerator {
    private let arch: String
    private let buildDir: URL
    private let headersDir: URL
    private let diskCopier: DiskCopier

    /// Default initializer
    /// - Parameters:
    ///   - arch: architecture of the build
    ///   - buildDir: directory where all *.swiftmodule products should be placed
    ///   - headersDir: directory where generated ObjC headers should be placed
    ///   - fileManager: fileManager instance
    init(
        arch: String,
        buildDir: URL,
        headersDir: URL,
        diskCopier: DiskCopier
    ) {
        self.arch = arch
        self.buildDir = buildDir
        self.headersDir = headersDir
        self.diskCopier = diskCopier
    }

    func generateFrom(
        artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> URL {
        /// Predict moduleName from the `*.swiftmodule` artifact
        let foundSwiftmoduleFile = artifactSwiftModuleFiles[.swiftmodule]
        guard let mainSwiftmoduleFile = foundSwiftmoduleFile else {
            throw MirroredLinkingSwiftcProductsGeneratorError.missingMainSwiftmoduleFileToGenerateFrom
        }
        let moduleName = mainSwiftmoduleFile.deletingPathExtension().lastPathComponent
        let modulePathOutput = buildDir
            .appendingPathComponent("\(moduleName).swiftmodule")
            .appendingPathComponent(arch)
            .appendingPathExtension("swiftmodule")
        let objcHeaderOutput = headersDir.appendingPathComponent("\(moduleName)-Swift.h")

        let generator = DiskSwiftcProductsGenerator(
            modulePathOutput: modulePathOutput,
            objcHeaderOutput: objcHeaderOutput,
            diskCopier: diskCopier
        )

        return try generator.generateFrom(
            artifactSwiftModuleFiles: artifactSwiftModuleFiles,
            artifactSwiftModuleObjCFile: artifactSwiftModuleObjCFile
        )
    }
}
