import Foundation
@testable import XCRemoteCache

class SwiftcMock: SwiftcProtocol {
    private let result: SwiftCResult
    init(mockingResult: SwiftCResult) {
        result = mockingResult
    }

    func mockCompilation() throws -> SwiftCResult {
        return result
    }
}
