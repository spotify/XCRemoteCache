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
import XCRemoteCache

/// Wrapper for a `swift-frontend` that skips compilation and
/// produces empty output files (.o). As a compilation dependencies
/// (.d) file, it copies all dependency files from the prebuild marker file
/// Fallbacks to a standard `swift-frontend` when the ramote cache is not applicable (e.g. modified sources)
public class XCSwiftcFrontendMain {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func main() {
        let env = ProcessInfo.processInfo.environment
        let command = ProcessInfo().processName
        let args = ProcessInfo().arguments
        var compile = false
        var emitModule = false
        var objcHeaderOutput: String?
        var moduleName: String?
        var target: String?
        var inputPaths: [String] = []
        var primaryInputPaths: [String] = []
        var outputPaths: [String] = []
        var dependenciesPaths: [String] = []
        var diagnosticsPaths: [String] = []
        var sourceInfoPath: String?
        var docPath: String?
        var supplementaryOutputFileMap: String?

        for i in 0..<args.count {
            let arg = args[i]
            switch arg {
            case "-c":
                compile = true
            case "-emit-module":
                emitModule = true
            case "-o":
                outputPaths.append(args[i + 1])
            case "-emit-objc-header-path":
                objcHeaderOutput = args[i + 1]
            case "-module-name":
                moduleName = args[i + 1]
            case "-target":
                target = args[i + 1]
            case "-serialize-diagnostics-path":
                // .dia
                diagnosticsPaths.append(args[i + 1])
            case "-emit-dependencies-path":
                // .d
                dependenciesPaths.append(args[i + 1])
            case "-emit-module-source-info-path":
                // .swiftsourceinfo
                sourceInfoPath = args[i + 1]
            case "-emit-module-doc-path":
                // .swiftsourceinfo
                docPath = args[i + 1]
            case "-primary-file":
                // .swift
                primaryInputPaths.append(args[i + 1])
            case "-supplementary-output-file-map":
                supplementaryOutputFileMap = args[i + 1]
            default:
                if arg.hasSuffix(".swift") {
                    inputPaths.append(arg)
                }
            }
        }
        // support either emitModule (the preflight step) or compilation
        // all other types of invocations (like -print-target-info) should be
        // automatically redirected to the original swift-frontend
        let argInput = SwiftFrontendArgInput(
            compile: compile,
            emitModule: emitModule,
            objcHeaderOutput: objcHeaderOutput,
            moduleName: moduleName,
            target: target,
            primaryInputPaths: primaryInputPaths,
            inputPaths: inputPaths,
            outputPaths: outputPaths,
            dependenciesPaths: dependenciesPaths,
            diagnosticsPaths: diagnosticsPaths,
            sourceInfoPath: sourceInfoPath,
            docPath: docPath,
            supplementaryOutputFileMap: supplementaryOutputFileMap
        )
        // swift-frontened is first invoked with some "probing" args like
        // -print-target-info
        guard emitModule != compile else {
            runFallback(envs: env)
        }

        do {
            let frontend = try XCSwiftFrontend(
                command: command,
                inputArgs: argInput,
                env: env,
                dependenciesWriter: FileDependenciesWriter.init,
                touchFactory: FileTouch.init)
            try frontend.run()
        } catch {
            runFallback(envs: env)
        }
    }

    private func runFallback(envs env: [String: String]) -> Never {
        let developerDir = env["DEVELOPER_DIR"]!
        // limitation: always using the Xcode's toolchain
        let swiftFrontendCommand = "\(developerDir)/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-frontend"

        let args = ProcessInfo().arguments
        let paramList = [swiftFrontendCommand] + args.dropFirst()
        let cargs = paramList.map { strdup($0) } + [nil]
        execvp(swiftFrontendCommand, cargs)

        /// C-function `execv` returns only when the command fails
        exit(1)
    }
}
