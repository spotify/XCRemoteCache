@testable import XCRemoteCache

import XCTest


class XcodeProbeImplTests: XCTestCase {

    private func generateOutput(returnString: String) -> ShellOutFunction {
        return { _, _, _, _ in returnString }
    }

    func testValidOutput() throws {
        let outputString = """
        Xcode 11.3.1
        Build version 11C505
        """
        let probe = XcodeProbeImpl(shell: generateOutput(returnString: outputString))

        let version = try probe.read()

        XCTAssertEqual(version.buildVersion, "11C505")
        XCTAssertEqual(version.version, "11.3.1")
    }

    func testFailingForInvalidOutput() throws {
        let outputString = ""
        let probe = XcodeProbeImpl(shell: generateOutput(returnString: outputString))

        XCTAssertThrowsError(try probe.read())
    }
}
