import Foundation
@testable import XCRemoteCache

class WorkerFake: Worker {
    private var errors: [Error] = []

    func appendAction(_ action: @escaping () throws -> Void) {
        do {
            try action()
        } catch {
            errors.append(error)
        }
    }

    func waitForResult() -> WorkerResult {
        defer {
            errors = []
        }
        if errors.isEmpty {
            return .successes
        }
        return .errors(errors)
    }
}
