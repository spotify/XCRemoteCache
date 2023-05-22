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
    public enum SwiftcStep {
        case compileFiles
        case emitModule(objcHeaderOutput: URL, modulePathOutput: URL)
    }
    
    /// Defines how a list of input files (*.swift) is passed to the invocation
    public enum CompilationFilesSource {
        /// defined in a separate file (via @/.../*.SwiftFileList)
        case fileList(String)
        /// explicitly passed a list of files
        case list([String])
    }
    
    /// Defines how a list of output files (*.d, *.o etc.) is passed to the invocation
    public enum CompilationFilesOutputs {
        /// defined in a separate file (via -output-file-map)
        case fileMap(String)
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

    let steps: [SwiftcStep]
//    let objcHeaderOutput: URL
    let moduleName: String
//    let modulePathOutput: URL
    /// A source that defines output files locations (.d, .swiftmodule etc.)
    let outputs: CompilationFilesOutputs
    let target: String
    /// A source that contains all input files for the swift module compilation
    let inputs: CompilationFilesSource
    let tempDir: URL
    let arch: String
    let prebuildDependenciesPath: String
    let mode: SwiftcMode
    /// File that stores all compilation invocation arguments
    let invocationHistoryFile: URL


    public init(
        config: XCRemoteCacheConfig,
        moduleName: String,
        steps: [SwiftcStep],
        outputs: CompilationFilesOutputs,
        target: String,
        inputs: CompilationFilesSource,
        // TODO: make sure it is required
        /// any workspace file path - all other intermediate files for this compilation
        /// are placed next to it. This path is used to infere the arch and TARGET_TEMP_DIR
        exampleWorkspaceFilePath: String
    ) throws {
//        self.objcHeaderOutput = URL(fileURLWithPath: objcHeaderOutput)
        self.moduleName = moduleName
//        self.modulePathOutput = URL(fileURLWithPath: modulePathOutput)
        self.steps = steps
        self.outputs = outputs
//        self.filemap = URL(fileURLWithPath: filemap)
        self.target = target
//        self.fileList = URL(fileURLWithPath: fileList)
        self.inputs = inputs
        // modulePathOutput is place in $TARGET_TEMP_DIR/Objects-normal/$ARCH/$TARGET_NAME.swiftmodule
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
        let steps: [SwiftcStep] = [
            .compileFiles,
            .emitModule(
                objcHeaderOutput: URL(fileURLWithPath: (input.objcHeaderOutput)),
                modulePathOutput: URL(fileURLWithPath: input.modulePathOutput)
            )
        ]
        let outputs = CompilationFilesOutputs.fileMap(input.filemap)
        let inputs = CompilationFilesSource.fileList(input.fileList)
        try self.init(
            config: config,
            moduleName: input.moduleName,
            steps: steps,
            outputs: outputs,
            target: input.target,
            inputs: inputs,
            exampleWorkspaceFilePath: input.modulePathOutput
        )
    }
    
    init(
        config: XCRemoteCacheConfig,
        input: SwiftFrontendArgInput
    ) throws {
        try self.init(
            config: config,
            objcHeaderOutput: input.objcHeaderOutput,
            moduleName: input.moduleName,
            modulePathOutput: input.modulePathOutput,
            filemap: input.filemap,
            target: input.target,
            fileList: input.fileList
        )
    }
}
