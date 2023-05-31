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
    /// Executes the criticial secion according to the required order
    /// - Parameter criticalSection: the block that should be synchronized
    func run(criticalSection: () -> Void ) throws
}

/// The default orchestrator that manages the order or swift-frontend invocations
/// For emit-module (the "first" process) action, it locks a shared file between all swift-frontend invcations,
/// verifies that the mocking can be done and continues the mocking/fallbacking along the lock release
/// For the compilation action, tries to ackquire a lock and waits until the "emit-module" makes a decision
/// if the compilation should be skipped and a "mocking" should used instead
class CommonSwiftFrontendOrchestrator {
    private let mode: SwiftcContext.SwiftcMode

    init(mode: SwiftcContext.SwiftcMode) {
        self.mode = mode
    }

    func run(criticalSection: () throws -> Void) throws {
        // TODO: implement synchronization in a separate PR
        try criticalSection()
    }
}
