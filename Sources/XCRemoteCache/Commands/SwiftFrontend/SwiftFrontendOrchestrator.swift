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

/// Manages  the `swift-frontend` logic
protocol SwiftFrontendOrchestrator {
    /// Executes the critical section according to the required order
    /// - Parameter criticalSection: the block that should be synchronized
    func run(criticalSection: () -> Void ) throws
}

/// The default orchestrator that manages the order or swift-frontend invocations
/// For emit-module (the "first" process) action, it locks a shared file between all swift-frontend invocations,
/// verifies that the mocking can be done and continues the mocking/fall-backing along the lock release
/// For the compilation action, tries to acquire a lock and waits until the "emit-module" makes a decision
/// if the compilation should be skipped and a "mocking" should used instead
class CommonSwiftFrontendOrchestrator {
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
    private let maxLockTimeout: TimeInterval

    init(
        mode: SwiftcContext.SwiftcMode,
        action: Action,
        lockAccessor: ExclusiveFileAccessor,
        maxLockTimeout: TimeInterval
    ) {
        self.mode = mode
        self.action = action
        self.lockAccessor = lockAccessor
        self.maxLockTimeout = maxLockTimeout
    }

    func run(criticalSection: () throws -> Void) throws {
        guard case .consumer(commit: .available) = mode else {
            // no need to lock anything - just allow fallbacking to the `swiftc or swift-frontend`
            // for a producer or a consumer where RC is disabled (we have already caught the
            // cache miss)
            try criticalSection()
            return
        }
        try executeMockAttemp(criticalSection: criticalSection)
    }

    private func executeMockAttemp(criticalSection: () throws -> Void) throws {
        switch action {
        case .emitModule:
            try validateEmitModuleStep(criticalSection: criticalSection)
        case .compile:
            try waitForEmitModuleLock(criticalSection: criticalSection)
        }
    }


    /// For emit-module, wrap the critical section with the shared lock so other processes (compilation)
    /// have to wait until emit-module finishes
    /// Once the emit-module is done, the "magical" string is saved to the file and the lock is released
    ///
    /// Note: The design of wrapping the entire "emit-module" has a small performance downside if inside
    /// the critical section, the code realizes that remote cache cannot be used
    /// (in practice - a new file has been added)
    /// None of compilation process (so with '-c' args) can continue until the entire emit-module logic finishes
    /// Because it is expected to happen not that often and emit-module is usually quite fast, this makes the
    /// implementation way simpler. If we ever want to optimize it, we should release the lock as early
    /// as we know, the remote cache cannot be used. Then all other compilation process (-c) can run
    /// in parallel with emit-module
    private func validateEmitModuleStep(criticalSection: () throws -> Void) throws {
        debugLog("starting the emit-module step: locking")
        try lockAccessor.exclusiveAccess { handle in
            debugLog("starting the emit-module step: locked")
            // writing to the file content proactively - incase the critical section never returns
            // (in case of a fallback to the local compilation), all awaiting swift-frontend processes
            // will be immediately unblocked
            handle.write(Self.self.emitModuleContent)
            try criticalSection()
            debugLog("lock file emit-module criticial end")
        }
    }

    /// Locks a shared file in a loop until its content is non-empty - meaning the "parent" emit-module
    /// has already finished
    private func waitForEmitModuleLock(criticalSection: () throws -> Void) throws {
        // emit-module process should really quickly obtain a lock (it is always invoked
        // by Xcode as a first process)
        var executed = false
        let startingDate = Date()
        while !executed {
            debugLog("lock file compilation trying to acquire a lock ....")
            try lockAccessor.exclusiveAccess { handle in
                if !handle.availableData.isEmpty {
                    // the file is not empty so the emit-module process is done with the "check"
                    debugLog("swift-frontend lock file is unlocked for compilation")
                    try criticalSection()
                    executed = true
                } else {
                    debugLog("swift-frontend lock file is not ready for compilation")
                }
            }
            // When a max locking time is achieved, execute anyway
            if !executed && Date().timeIntervalSince(startingDate) > self.maxLockTimeout {
                errorLog("""
                Executing command \(action) without lock synchronization. That may be cause by the\
                crashed or extremely long emit-module. Contact XCRemoteCache authors about this error.
                """)
                try criticalSection()
                executed = true
            }
        }
    }
}
