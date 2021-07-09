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
