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

enum XCACToolError: Error {
    /// none of ObjC or Swift source output is defined
    case noOutputFile
}

struct ACToolContext {
    let tempDir: URL
    let objcOutput: URL?
    let swiftOutput: URL?
    let markerURL: URL

    init(
        config: XCRemoteCacheConfig,
        objcOutput: String?,
        swiftOutput: String?
    ) throws {
        self.objcOutput = objcOutput.map(URL.init(fileURLWithPath:))
        self.swiftOutput = swiftOutput.map(URL.init(fileURLWithPath:))

        // infer the target from either objc or swift
        guard let sourceOutputFile = self.objcOutput ?? self.swiftOutput else {
            throw XCACToolError.noOutputFile
        }

        // sourceOutputFile has a format $TARGET_TEMP_DIR/DerivedSources/GeneratedAssetSymbols.{swift|h}
        // That may be subject to change for other Xcode versions
        self.tempDir = sourceOutputFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        self.markerURL = tempDir.appendingPathComponent(config.modeMarkerPath)
    }
}

public class XCACTool {

    private let args: [String]
    private let objcOutput: String?
    private let swiftOutput: String?
    private let shellOut: ShellOut

    public init(
        args: [String],
        objcOutput: String?,
        swiftOutput: String?
    ) {
        self.args = args
        self.objcOutput = objcOutput
        self.swiftOutput = swiftOutput
        self.shellOut = ProcessShellOut()
    }

    public func run() throws {
        // Alternatively, read $PWD
        let currentDir = FileManager.default.currentDirectoryPath
        let fileAccessor: FileAccessor = FileManager.default
        let config: XCRemoteCacheConfig
        let context: ACToolContext
        let srcRoot: URL = URL(fileURLWithPath: currentDir)
        config = try XCRemoteCacheConfigReader(srcRootPath: srcRoot.path, fileReader: fileAccessor)
            .readConfiguration()
        context = try ACToolContext(
            config: config,
            objcOutput: objcOutput,
            swiftOutput: swiftOutput
        )

        let markerReader = FileMarkerReader(context.markerURL, fileManager: fileAccessor)
        let markerWriter = FileMarkerWriter(context.markerURL, fileAccessor: fileAccessor)

        // 0. Let the command run
        try fallbackToDefaultAndWait(command: "actool", args: args)

        // 1. do nothing if the RC is disabled
        guard markerReader.canRead() else {
            return
        }

        // 2. Read meta's sources files & fingerprint
        // 3. Compare local vs meta's fingerprint
        // 4. Disable RC if the is fingerprint doesn't match
    }

    private func fallbackToDefaultAndWait(command: String = "actool", args: [String]) throws {
        defaultLog("Fallbacking to compilation using \(command).")
        do {
            try shellOut.callExternalProcessAndWait(
                command: command,
                invocationArgs: Array(args.dropFirst()),
                envs: ProcessInfo.processInfo.environment
            )
        } catch ShellError.statusError(_, let exitCode) {
            exit(exitCode)
        }
    }
}
