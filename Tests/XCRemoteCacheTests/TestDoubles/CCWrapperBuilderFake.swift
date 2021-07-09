import Foundation
@testable import XCRemoteCache

class CCWrapperBuilderFake: CCWrapperBuilder {
    func compile(to destination: URL, commitSha: String) throws {}
}
