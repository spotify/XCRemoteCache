import Foundation
@testable import XCRemoteCache

class MarkerWriterSpy: MarkerWriter {
    enum State: Equatable {
        case initial
        case enabled([URL])
        case disabled
    }

    private(set) var state: State = .initial
    func enable(dependencies: [URL]) throws {
        state = .enabled(dependencies)
    }

    func disable() throws {
        state = .disabled
    }
}
