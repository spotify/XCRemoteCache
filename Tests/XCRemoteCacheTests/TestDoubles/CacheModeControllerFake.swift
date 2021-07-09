import Foundation

@testable import XCRemoteCache

class CacheModeControllerFake: CacheModeController {

    var enabled = false
    var disabled = false
    var shouldDisable = false
    var dependencies: [URL] = []

    func enable(allowedInputFiles: [URL], dependencies: [URL]) throws {
        enabled = true
        self.dependencies = dependencies
    }

    func disable() throws {
        disabled = true
    }

    func isEnabled() throws -> Bool {
        return enabled
    }

    func shouldDisable(for commit: RemoteCommitInfo) -> Bool {
        return shouldDisable
    }
}
