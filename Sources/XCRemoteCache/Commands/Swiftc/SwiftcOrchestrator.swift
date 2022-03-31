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

/// Performs the `swiftc` logic
/// Depending on the mode, tries to mock the compilation (consumer)
/// or generates and uploads artifacts (producer)
class SwiftcOrchestrator {
    private let swiftc: SwiftcProtocol
    private let mode: SwiftcContext.SwiftcMode
    // swiftc command that should be called to generate artifacts
    private let swiftcCommand: String
    private let objcHeaderOutput: URL
    private let moduleOutput: URL
    private let arch: String
    private let artifactBuilder: ArtifactSwiftProductsBuilder
    private let shellOut: ShellOut
    private let producerFallbackCommandProcessors: [ShellCommandsProcessor]
    private let invocationStorage: InvocationStorage

    init(
        mode: SwiftcContext.SwiftcMode,
        swiftc: SwiftcProtocol,
        swiftcCommand: String,
        objcHeaderOutput: URL,
        moduleOutput: URL,
        arch: String,
        artifactBuilder: ArtifactSwiftProductsBuilder,
        producerFallbackCommandProcessors: [ShellCommandsProcessor],
        invocationStorage: InvocationStorage,
        shellOut: ShellOut
    ) {
        self.mode = mode
        self.swiftc = swiftc
        self.swiftcCommand = swiftcCommand
        self.objcHeaderOutput = objcHeaderOutput
        self.moduleOutput = moduleOutput
        self.arch = arch
        self.artifactBuilder = artifactBuilder
        self.producerFallbackCommandProcessors = producerFallbackCommandProcessors
        self.invocationStorage = invocationStorage
        self.shellOut = shellOut
    }

    private var invocationArgs: [String] {
        let args = ProcessInfo().arguments
        // first arg is a path to the current command, drop it
        return Array(args.dropFirst())
    }

    private func fallbackToDefault(command: String = "swiftc") {
        defaultLog("Fallbacking to compilation using \(command).")
        shellOut.switchToExternalProcess(command: command, invocationArgs: invocationArgs)
    }

    private func fallbackToDefaultAndWait(command: String = "swiftc", args: [String]) throws {
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

    /// calls all invocations one-by-one
    /// - Parameter invocations: array or invocations: a command and all arguments
    private func callExternalInvocations(invocations: [[String]]) throws {
        try invocations.forEach { fullInvocation in
            guard let command = fullInvocation.first else {
                throw InvocationStorageError.corruptedStorage
            }
            try fallbackToDefaultAndWait(command: command, args: fullInvocation)
        }
    }

    func run() throws {
        switch mode {
        case .consumer(.available):
            let compileStepResult = try swiftc.mockCompilation()
            do {
                if case .forceFallback = compileStepResult {
                    // last-time fallback (probably a new swift file was added to the target)
                    // we are responsible to call all gathered compilation steps in compilation history
                    let historyCommandsToCall = try invocationStorage.retrieveAll()
                    try callExternalInvocations(invocations: historyCommandsToCall)
                    fallbackToDefault(command: swiftcCommand)
                } else {
                    // save the current compilation invocation to the history file
                    try invocationStorage.store(args: invocationArgs)
                }
            } catch {
                // The critical section is protected by a lock. Some other process already called compilation history
                // We only need to call our current step then
                fallbackToDefault(command: swiftcCommand)
            }
        case .consumer:
            fallbackToDefault(command: swiftcCommand)
        case .producerFast:
            let compileStepResult = try swiftc.mockCompilation()
            if case .forceFallback = compileStepResult {
                // cannot reuse cached artifact. Build it locally and upload to the server just as for the producer
                fallthrough
            }
        case .producer:
            var swiftcArgs = ProcessInfo().arguments
            swiftcArgs = try producerFallbackCommandProcessors.reduce(swiftcArgs) { args, processor in
                try processor.applyArgsRewrite(args)
            }
            try fallbackToDefaultAndWait(command: swiftcCommand, args: swiftcArgs)
            // move generated .h to the location where artifact creator expects it
            try artifactBuilder.includeObjCHeaderToTheArtifact(arch: arch, headerURL: objcHeaderOutput)
            // move generated .swiftmodule to the location where artifact creator expects it
            try artifactBuilder.includeModuleDefinitionsToTheArtifact(arch: arch, moduleURL: moduleOutput)

            try producerFallbackCommandProcessors.forEach {
                try $0.postCommandProcessing()
            }
        }
    }
}
