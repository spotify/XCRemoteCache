import Foundation
@testable import XCRemoteCache

class TouchSpy: Touch {
    private(set) var touched = false
    func touch() throws {
        touched = true
    }
}
