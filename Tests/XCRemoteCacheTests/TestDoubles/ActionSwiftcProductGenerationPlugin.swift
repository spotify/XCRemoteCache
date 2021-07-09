import Foundation
@testable import XCRemoteCache

class ActionSwiftcProductGenerationPlugin: SwiftcProductGenerationPlugin {
    private let action: () throws -> Void

    init(_ action: @escaping () throws -> Void) {
        self.action = action
    }

    func generate(for: SwiftCompilationInfo) throws {
        try action()
    }
}
