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

@testable import XCRemoteCache
import XCTest

class DispatchGroupParallelizationWorkerTests: FileXCTestCase {

    private static let errorAction: () throws -> Void = { throw "Error" }
    private static let successAction: () throws -> Void = {}

    func testReportsSuccessForNoActions() throws {
        let worker = DispatchGroupParallelizationWorker()

        let result = worker.waitForResult()

        guard case .successes = result else {
            throw "Unexpected result: \(result)"
        }
    }

    func testReportsSuccessSuccessfulActions() throws {
        let worker = DispatchGroupParallelizationWorker()
        worker.appendAction(Self.successAction)
        worker.appendAction(Self.successAction)

        let result = worker.waitForResult()

        guard case .successes = result else {
            throw "Unexpected result: \(result)"
        }
    }

    func testReportsError() throws {
        let worker = DispatchGroupParallelizationWorker()
        worker.appendAction(Self.successAction)
        worker.appendAction(Self.errorAction)

        let result = worker.waitForResult()

        guard case .errors = result else {
            throw "Unexpected result: \(result)"
        }
    }

    func testReportAllErrors() throws {
        let worker = DispatchGroupParallelizationWorker()
        worker.appendAction(Self.errorAction)
        worker.appendAction(Self.errorAction)

        let result = worker.waitForResult()

        guard case .errors(let errors) = result else {
            throw "Unexpected result: \(result)"
        }
        XCTAssertEqual(errors.count, 2)
    }

    func testErrorsAreReportedOnlyForTheFirstWait() throws {
        let worker = DispatchGroupParallelizationWorker()
        worker.appendAction(Self.errorAction)
        _ = worker.waitForResult()

        let result = worker.waitForResult()

        guard case .successes = result else {
            throw "Unexpected result: \(result)"
        }
    }
}
