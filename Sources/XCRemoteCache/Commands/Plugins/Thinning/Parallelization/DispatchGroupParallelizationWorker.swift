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

enum WorkerResult {
    case successes
    case errors([Error])
}

/// Worker that manages executing blocks
protocol Worker {
    /// Adding an action to run in parallel
    /// - Parameter action: action to perform
    func appendAction(_ action: @escaping () throws -> Void)
    /// Wait for actions to finish
    /// - Returns: execution result of all appended actions
    func waitForResult() -> WorkerResult
}

/// Worker that executes actions in pararell using DispatchGroup
/// Warning! This implementation is not thread safe: all functions have to be called from the same thread
class DispatchGroupParallelizationWorker: Worker {
    private let group: DispatchGroup
    private let queue: DispatchQueue
    private let qos: DispatchQoS.QoSClass
    private var observedErrors: [Error]

    /// Default initializer
    /// - Parameter qos: QoS of the background queue to execute actions
    init(qos: DispatchQoS.QoSClass = .userInteractive) {
        group = DispatchGroup()
        queue = DispatchQueue(
            label: "DispatchGroupParallelization",
            qos: .userInteractive,
            attributes: .concurrent,
            autoreleaseFrequency: .inherit,
            target: .global(qos: qos)
        )
        observedErrors = []
        self.qos = qos
    }


    func appendAction(_ action: @escaping () throws -> Void) {
        group.enter()
        queue.async {
            do {
                try action()
            } catch {
                // Errors are not expected to be frequent so just enqueing another block to the working group
                self.group.enter()
                self.queue.async(group: self.group, qos: self.qos.dispatchQoS, flags: .barrier) {
                    self.observedErrors.append(error)
                    self.group.leave()
                }
            }
            self.group.leave()
        }
    }

    func waitForResult() -> WorkerResult {
        group.wait()
        if observedErrors.isEmpty {
            return .successes
        }
        defer {
            observedErrors = []
        }
        return .errors(observedErrors)
    }
}

extension DispatchQoS.QoSClass {
    /// Trivial transform from DispatchQoS.QoSClass to DispatchQoS
    var dispatchQoS: DispatchQoS {
        switch self {
        case .background: return .background
        case .default: return .default
        case .unspecified: return .unspecified
        case .userInitiated: return .userInitiated
        case .userInteractive: return .userInteractive
        case .utility: return .utility
        @unknown default:
            return .default
        }
    }
}
