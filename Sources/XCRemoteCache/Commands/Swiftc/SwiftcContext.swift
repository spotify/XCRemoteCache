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

public struct SwiftcContext {
    /// Describes the action if the module emit should happen
    /// that generates .swiftmodule and/or -Swift.h
    public struct SwiftcStepEmitModule: Equatable {
        // where the -Swift.h should be placed
        let objcHeaderOutput: URL
        // where should the .swiftmodule be placed
        let modulePathOutput: URL
        // might be passed as an explicit argument in the swiftc
        // -emit-dependencies-path
        let dependencies: URL?
    }

    /// Which files (from the list of all files in the module)
    /// should be compiled in this process
    public enum SwiftcStepCompileFilesScope: Equatable {
        /// used if only emit module should be done
        case none
        case all
        case subset([URL])
    }

    /// Describes which steps should be done as a part of this process
    public struct SwiftcSteps: Equatable {
        /// which files should be compiled
        let compileFilesScope: SwiftcStepCompileFilesScope
        /// if a module should be generated
        let emitModule: SwiftcStepEmitModule?
    }

    /// Defines how a list of input files (*.swift) is passed to the invocation
    public enum CompilationFilesSource: Equatable {
        /// defined in a separate file (via @/.../*.SwiftFileList)
        case fileList(String)
        /// explicitly passed a list of files
        case list([String])
    }

    /// Defines how a list of output files (*.d, *.o etc.) is passed to the invocation
    public enum CompilationFilesInputs: Equatable {
        /// defined in a separate file (via -output-file-map)
        case fileMap(String)
        /// defined in a separate file (via -supplementary-output-file-map)
        case supplementaryFileMap(String)
        /// explicitly passed in the invocation
        case map([String: SwiftFileCompilationInfo])
    }

    enum SwiftcMode: Equatable {
        case producer
        /// Commit sha of the commit to use during remote cache
        case consumer(commit: RemoteCommitInfo)
        /// Remote artifact exists and can be optimistically used in place of a local compilation
        case producerFast
    }

    let steps: SwiftcSteps
    let moduleName: String
    /// A source that defines output files locations (.d, .swiftmodule etc.)
    let inputs: CompilationFilesInputs
    let target: String
    /// A source that contains all input files for the swift module compilation
    let compilationFiles: CompilationFilesSource
    let tempDir: URL
    let arch: String
    let prebuildDependenciesPath: String
    let mode: SwiftcMode
    /// File that stores all compilation invocation arguments
    let invocationHistoryFile: URL

    public init(
        config: XCRemoteCacheConfig,
        moduleName: String,
        steps: SwiftcSteps,
        inputs: CompilationFilesInputs,
        target: String,
        compilationFiles: CompilationFilesSource,
        /// any workspace file path - all other intermediate files for this compilation
        /// are placed next to it. This path is used to infer the arch and TARGET_TEMP_DIR
        exampleWorkspaceFilePath: String
    ) throws {
        self.moduleName = moduleName
        self.steps = steps
        self.inputs = inputs
        self.target = target
        self.compilationFiles = compilationFiles
        // exampleWorkspaceFilePath has a format $TARGET_TEMP_DIR/Objects-normal/$ARCH/some.file
        // That may be subject to change for other Xcode versions
        tempDir = URL(fileURLWithPath: exampleWorkspaceFilePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        arch = URL(fileURLWithPath: exampleWorkspaceFilePath).deletingLastPathComponent().lastPathComponent

        let srcRoot: URL = URL(fileURLWithPath: config.sourceRoot)
        let remoteCommitLocation = URL(fileURLWithPath: config.remoteCommitFile, relativeTo: srcRoot)
        prebuildDependenciesPath = config.prebuildDiscoveryPath
        switch config.mode {
        case .consumer:
            let remoteCommit = RemoteCommitInfo(try? String(contentsOf: remoteCommitLocation).trim())
            mode = .consumer(commit: remoteCommit)
        case .producer:
            mode = .producer
        case .producerFast:
            let remoteCommit = RemoteCommitInfo(try? String(contentsOf: remoteCommitLocation).trim())
            switch remoteCommit {
            case .unavailable:
                mode = .producer
            case .available:
                mode = .producerFast
            }
        }
        invocationHistoryFile = URL(fileURLWithPath: config.compilationHistoryFile, relativeTo: tempDir)
    }

    init(
        config: XCRemoteCacheConfig,
        input: SwiftcArgInput
    ) throws {
        let steps = SwiftcSteps(
            compileFilesScope: .all,
            emitModule: SwiftcStepEmitModule(
                objcHeaderOutput: URL(fileURLWithPath: (input.objcHeaderOutput)),
                modulePathOutput: URL(fileURLWithPath: input.modulePathOutput),
                // in `swiftc`, .d dependencies are pass in the output filemap
                dependencies: nil
            )
        )
        let inputs = CompilationFilesInputs.fileMap(input.filemap)
        let compilationFiles = CompilationFilesSource.fileList(input.fileList)
        try self.init(
            config: config,
            moduleName: input.moduleName,
            steps: steps,
            inputs: inputs,
            target: input.target,
            compilationFiles: compilationFiles,
            exampleWorkspaceFilePath: input.modulePathOutput
        )
    }

    init(
        config: XCRemoteCacheConfig,
        input: SwiftFrontendArgInput
    ) throws {
        self = try input.generateSwiftcContext(config: config)
    }
}
