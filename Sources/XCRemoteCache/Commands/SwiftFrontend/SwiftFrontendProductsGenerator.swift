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

enum DiskSwiftFrontendProductsGeneratorError: Error {
    /// Emittiing module is available only from emit-module action
    case requestedEmitingModuleForInvalidAction(SwiftFrontendAction)
    /// When a generator was asked to generate unknown swiftmodule extension file
    /// Probably a programmer error: asking to generate excessive extensions, not listed in
    /// `SwiftmoduleFileExtension.SwiftmoduleExtensions`
    case unknownSwiftmoduleFile
}

struct SwiftFrontendEmitModuleProductsGeneratorOutput {
    let swiftmoduleDir: URL
    let objcHeaderFile: URL
}

struct SwiftFrontendCompilationProductsGeneratorOutput {
    // TODO:
}

/// Generates SwiftFrontend product to the expected location
protocol SwiftFrontendProductsGenerator {
    /// Generates products for the emit-module invocation from given files
    /// - Returns: location dir where .swiftmodule and ObjC header files have been placed
    func generateEmitModuleFrom(
        artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> SwiftFrontendEmitModuleProductsGeneratorOutput
    
    /// Generates products for the compilation(s) invocation from given file(s)
    /// - Returns: location dir where .swiftmodule and ObjC header files have been placed
    func generateCompilationFrom(
        // TODO:
    ) throws -> SwiftFrontendCompilationProductsGeneratorOutput
}

/// Generator that produces all products in the locations where Xcode expects it, using provided disk copier
class DiskSwiftFrontendProductsGenerator: SwiftFrontendProductsGenerator {
    private let action: SwiftFrontendAction
    private let diskCopier: DiskCopier

    init(
        action: SwiftFrontendAction,
        diskCopier: DiskCopier
    ) {
        self.action = action
        self.diskCopier = diskCopier
    }

    func generateEmitModuleFrom(
        artifactSwiftModuleFiles sourceAtifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> SwiftFrontendEmitModuleProductsGeneratorOutput {
        guard case .emitModule(emitModuleInfo: let info, inputFiles: let files) = action else {
            throw DiskSwiftFrontendProductsGeneratorError.requestedEmitingModuleForInvalidAction(action)
        }
        
        let modulePathOutput = info.output
        let objcHeaderOutput = info.objcHeader
        let modulePathBasename = modulePathOutput.deletingPathExtension()
        // all swiftmodule-related should be located next to the ".swiftmodule"
        let destinationSwiftmodulePaths = Dictionary(
            uniqueKeysWithValues: SwiftmoduleFileExtension.SwiftmoduleExtensions
                .map { ext, _ in
                    (ext, modulePathBasename.appendingPathExtension(ext.rawValue))
                }
        )
        
        // Move cached -Swift.h file to the expected location
        try diskCopier.copy(file: artifactSwiftModuleObjCFile, destination: objcHeaderOutput)
        for (ext, url) in sourceAtifactSwiftModuleFiles {
            let dest = destinationSwiftmodulePaths[ext]
            guard let destination = dest else {
                throw DiskSwiftFrontendProductsGeneratorError.unknownSwiftmoduleFile
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
        return .init(
            swiftmoduleDir: modulePathOutput.deletingLastPathComponent(),
            objcHeaderFile: objcHeaderOutput
        )
    }
    
    func generateCompilationFrom() throws -> SwiftFrontendCompilationProductsGeneratorOutput {
        // TODO:
        return .init()
    }
}
