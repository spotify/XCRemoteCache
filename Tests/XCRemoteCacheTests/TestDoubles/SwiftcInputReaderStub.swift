import Foundation
@testable import XCRemoteCache

class SwiftcInputReaderStub: SwiftcInputReader {
    private let info: SwiftCompilationInfo
    init(info: SwiftCompilationInfo) {
        self.info = info
    }

    init() {
        let defaultCompilationInfo = SwiftModuleCompilationInfo(
            dependencies: nil,
            swiftDependencies: ""
        )
        info = .init(info: defaultCompilationInfo, files: [])
    }

    func read() throws -> SwiftCompilationInfo {
        return info
    }
}
