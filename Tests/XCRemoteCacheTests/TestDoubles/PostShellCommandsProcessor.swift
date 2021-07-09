import Foundation
@testable import XCRemoteCache

class PostShellCommandsProcessor: ShellCommandsProcessor {
    private let action: () throws -> Void
    init(_ action: @escaping () throws -> Void) {
        self.action = action
    }

    func postCommandProcessing() throws {
        try action()
    }

    func applyArgsRewrite(_ args: [String]) throws -> [String] {
        args
    }
}
