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

public class XCSwiftFrontend: XCSwiftAbstract<SwiftFrontendArgInput> {
    // don't lock individual compilation invocations for more than 10s
    private static let MaxLockingTimeout: TimeInterval = 10
    private let env: [String: String]

    public init(
        command: String,
        inputArgs: SwiftFrontendArgInput,
        env: [String: String],
        dependenciesWriter: @escaping (URL, FileManager) -> DependenciesWriter,
        touchFactory: @escaping (URL, FileManager) -> Touch
    ) throws {
        self.env = env
        super.init(
            command: command,
            inputArgs: inputArgs,
            dependenciesWriter: dependenciesWriter,
            touchFactory: touchFactory
        )
    }

    override func buildContext() throws -> (XCRemoteCacheConfig, SwiftcContext) {
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        let context: SwiftcContext

        let srcRoot: URL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        config = try XCRemoteCacheConfigReader(srcRootPath: srcRoot.path, fileReader: fileManager)
            .readConfiguration()
        context = try SwiftcContext(config: config, input: inputArgs)
        // do not cache this context, as it is subject to change when
        // the emit-module finds that the cached artifact cannot be used
        return (config, context)
    }

    override public func run() throws {
        do {
            /// The LLBUILD_BUILD_ID ENV that describes the swiftc (parent) invocation
            let llbuildId: String = try env.readEnv(key: "LLBUILD_BUILD_ID")
            let (_, context) = try buildContext()

            let sharedLockFileURL = XCSwiftFrontend.generateLlbuildIdSharedLockUrl(
                llbuildId: llbuildId,
                tmpDir: context.tempDir
            )
            let sharedLock = ExclusiveFile(sharedLockFileURL, mode: .override)

            let action: CommonSwiftFrontendOrchestrator.Action = inputArgs.emitModule ? .emitModule : .compile
            let swiftFrontendOrchestrator = CommonSwiftFrontendOrchestrator(
                mode: context.mode,
                action: action,
                lockAccessor: sharedLock,
                maxLockTimeout: Self.self.MaxLockingTimeout
            )

            try swiftFrontendOrchestrator.run(criticalSection: super.run)
        } catch {
            // Splitting into 2 invocations as os_log truncates a massage
            defaultLog("Cannot correctly orchestrate the \(command) with params \(inputArgs)")
            defaultLog("Cannot correctly orchestrate error: \(error)")
            throw error
        }
    }
}

extension XCSwiftFrontend {
    /// The file is used to sycnhronize mutliple swift-frontend invocations
    static func generateLlbuildIdSharedLockUrl(llbuildId: String, tmpDir: URL) -> URL {
        return tmpDir.appendingPathComponent(llbuildId).appendingPathExtension("lock")
    }
}
