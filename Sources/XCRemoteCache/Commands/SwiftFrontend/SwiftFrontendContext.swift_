// Copyright (c) 2023 Spotify AB.
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

struct SwiftFrontendContext {
    enum SwiftFrontendMode: Equatable {
        case producer
        /// Commit sha of the commit to use during remote cache
        case consumer(commit: RemoteCommitInfo)
        /// Remote artifact exists and can be optimistically used in place of a local compilation
        case producerFast
    }
    
    let moduleName: String
    let target: String
    let tempDir: URL
    let arch: String
    let prebuildDependenciesPath: String
    let mode: SwiftFrontendMode
    /// File that stores all compilation invocation arguments
    let invocationHistoryFile: URL
    let action: SwiftFrontendAction
    /// The LLBUILD_BUILD_ID ENV that describes the swiftc (parent) invocation
    let llbuildId: String


    private init(
        config: XCRemoteCacheConfig,
        env: [String: String],
        moduleName: String,
        target: String,
        action: SwiftFrontendAction
    ) throws {
        self.moduleName = moduleName
        self.target = target
        self.action = action
        llbuildId = try env.readEnv(key: "LLBUILD_BUILD_ID")
        
        tempDir = action.tmpDir
        arch = action.arch

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
        env: [String: String],
        input: SwiftFrontendArgInput,
        action: SwiftFrontendAction
    ) throws {
        try self.init(
            config: config,
            env: env,
            moduleName: action.moduleName,
            target: action.target,
            action: action
        )
    }
}

