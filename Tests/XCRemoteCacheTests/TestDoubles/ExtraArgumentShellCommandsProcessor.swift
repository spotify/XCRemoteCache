import Foundation
@testable import XCRemoteCache

class ExtraArgumentShellCommandsProcessor: ShellCommandsProcessor {
    private let extra: String

    init(_ extra: String) {
        self.extra = extra
    }

    func postCommandProcessing() throws {}

    func applyArgsRewrite(_ args: [String]) throws -> [String] {
        args + [extra]
    }
}
