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

/// Generator that produces all products in the DerivedData's Products locations, using provided disk copier
class ThinningDiskSwiftcProductsGenerator: SwiftcProductsGenerator {
    private let destinationSwiftmodulePaths: [SwiftmoduleFileExtension: URL]
    private let modulePathOutput: URL
    private let objcHeaderOutput: URL
    private let diskCopier: DiskCopier

    init(
        modulePathOutput: URL,
        objcHeaderOutput: URL,
        diskCopier: DiskCopier
    ) {
        self.modulePathOutput = modulePathOutput
        let modulePathBasename = modulePathOutput.deletingPathExtension()
        let modulePathDir = modulePathOutput.deletingLastPathComponent()
        let moduleName = modulePathBasename.lastPathComponent
        // all swiftmodule-related should be located next to the ".swiftmodule"
        // except of '.swiftsourceinfo', which should be placed in 'Project' dir
        destinationSwiftmodulePaths = Dictionary(
            uniqueKeysWithValues: SwiftmoduleFileExtension.SwiftmoduleExtensions
                .map { ext, _ in
                    switch ext {
                    case .swiftsourceinfo:
                        let dest = modulePathDir.appendingPathComponent("Project")
                            .appendingPathComponent(moduleName)
                            .appendingPathExtension(ext.rawValue)
                        return (ext, dest)
                    default:
                        return (ext, modulePathBasename.appendingPathExtension(ext.rawValue))
                    }
                }
        )
        self.objcHeaderOutput = objcHeaderOutput
        self.diskCopier = diskCopier
    }

    func generateFrom(
        artifactSwiftModuleFiles sourceAtifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> URL {
        // Move cached -Swift.h file to the expected location
        try diskCopier.copy(file: artifactSwiftModuleObjCFile, destination: objcHeaderOutput)
        for (ext, url) in sourceAtifactSwiftModuleFiles {
            let dest = destinationSwiftmodulePaths[ext]
            guard let destination = dest else {
                throw DiskSwiftcProductsGeneratorError.unknownSwiftmoduleFile
            }
            do {
                // Move cached .swiftmodule to the expected location
                try diskCopier.copy(file: url, destination: destination)
            } catch {
                if case .required = SwiftmoduleFileExtension.SwiftmoduleExtensions[ext] {
                    throw error
                } else {
                    infoLog("Optional .\(ext) file not found in the artifact at: \(destination.path)")
                }
            }
        }

        // Build parent dir of the .swiftmodule file that contains a module
        return modulePathOutput.deletingLastPathComponent()
    }
}
