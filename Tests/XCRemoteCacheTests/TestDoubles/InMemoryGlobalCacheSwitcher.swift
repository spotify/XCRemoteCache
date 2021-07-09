import Foundation
@testable import XCRemoteCache

class InMemoryGlobalCacheSwitcher: GlobalCacheSwitcher {
    enum State: Equatable {
        case enabled(sha: String)
        case disabled
    }

    private(set) var state = State.disabled

    func enable(sha: String) throws {
        state = .enabled(sha: sha)
    }

    func disable() throws {
        state = .disabled
    }
}
