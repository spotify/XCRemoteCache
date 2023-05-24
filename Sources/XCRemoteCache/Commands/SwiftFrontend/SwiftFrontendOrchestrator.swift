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

/// Performs the `swift-frontend` logic:
/// For emit-module (the "first" process) action, it locks a shared file between all swift-frontend invcations,
/// verifies that the mocking can be done and continues the mocking/fallbacking along the lock release
/// For the compilation action, tries to ackquire a lock and waits until the "emit-module" makes a decision
/// if the compilation should be skipped and a "mocking" should used instead
class SwiftFrontendOrchestrator {
    /// Content saved to the shared file
    /// Safe to use forced unwrapping
    private static let emitModuleContent = "done".data(using: .utf8)!

    enum Action {
        case emitModule
        case compile
    }
    private let mode: SwiftcContext.SwiftcMode
    private let action: Action
    private let lockAccessor: ExclusiveFileAccessor

    init(
        mode: SwiftcContext.SwiftcMode,
        action: Action,
        lockAccessor: ExclusiveFileAccessor
    ) {
        self.mode = mode
        self.action = action
        self.lockAccessor = lockAccessor
    }

    func run() throws {
        guard case .consumer(commit: .available) = mode else {
            // no need to lock anything - just allow fallbacking to the `swiftc or swift-frontend`
            return
        }
        try waitForEmitModuleLock()
    }

    private func executeMockAttemp() throws {
        switch action {
        case .emitModule:
            try validateEmitModuleStep()
        case .compile:
            try waitForEmitModuleLock()
        }
    }

    private func validateEmitModuleStep() throws {
        try lockAccessor.exclusiveAccess { handle in
            // TODO: check if the mocking compilation can happen (make sure
            // all input files are listed in the list of dependencies)

            handle.write(SwiftFrontendOrchestrator.emitModuleContent)
        }
    }

    /// Locks a shared file in a loop until its content non-empty, which means the "parent" emit-module has finished
    private func waitForEmitModuleLock() throws {
        while true {
            // TODO: add a max timeout
            try lockAccessor.exclusiveAccess { handle in
                if !handle.availableData.isEmpty {
                    // the file is not empty so emit-module is done with the "check"
                    return
                }
            }
        }
    }
}
