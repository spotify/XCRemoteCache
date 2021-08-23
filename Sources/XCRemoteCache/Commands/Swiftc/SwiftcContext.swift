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
    enum SwiftcMode: Equatable {
        case producer
        /// Commit sha of the commit to use during remote cache
        case consumer(commit: RemoteCommitInfo)
    }

    let objcHeaderOutput: URL
    let moduleName: String
    let modulePathOutput: URL
    /// File that defines output files locations (.d, .swiftmodule etc.)
    let filemap: URL
    let target: String
    /// File that contains input files for the swift module compilation
    let fileList: URL
    let tempDir: URL
    let arch: String
    let prebuildDependenciesPath: String
    let mode: SwiftcMode
    /// File that stores all compilation invocation arguments
    let invocationHistoryFile: URL


    public init(
        config: XCRemoteCacheConfig,
        objcHeaderOutput: String,
        moduleName: String,
        modulePathOutput: String,
        filemap: String,
        target: String,
        fileList: String
    ) throws {
        self.objcHeaderOutput = URL(fileURLWithPath: objcHeaderOutput)
        self.moduleName = moduleName
        self.modulePathOutput = URL(fileURLWithPath: modulePathOutput)
        self.filemap = URL(fileURLWithPath: filemap)
        self.target = target
        self.fileList = URL(fileURLWithPath: fileList)
        // modulePathOutput is place in $TARGET_TEMP_DIR/Objects-normal/$ARCH/$TARGET_NAME.swiftmodule
        // That may be subject to change for other Xcode versions
        tempDir = URL(fileURLWithPath: modulePathOutput)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        arch = URL(fileURLWithPath: modulePathOutput).deletingLastPathComponent().lastPathComponent

        let srcRoot: URL = URL(fileURLWithPath: config.sourceRoot)
        let remoteCommitLocation = URL(fileURLWithPath: config.remoteCommitFile, relativeTo: srcRoot)
        prebuildDependenciesPath = config.prebuildDiscoveryPath
        switch config.mode {
        case .consumer:
            let remoteCommit = RemoteCommitInfo(try? String(contentsOf: remoteCommitLocation).trim())
            mode = .consumer(commit: remoteCommit)
        case .producer:
            mode = .producer
        }
        invocationHistoryFile = URL(fileURLWithPath: config.compilationHistoryFile, relativeTo: tempDir)
    }

    init(
        config: XCRemoteCacheConfig,
        input: SwiftcArgInput
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
