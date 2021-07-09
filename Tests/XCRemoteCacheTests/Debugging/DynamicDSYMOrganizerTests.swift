@testable import XCRemoteCache
import XCTest

class DynamicDSYMOrganizerTests: FileXCTestCase {
    struct ShellCall: Equatable {
        let command: String
        let args: [String]
    }

    private var shellCommands: [ShellCall] = []
    private var shell: ShellCallFunction!
    private let productURL: URL = "product"
    private var dSYMPath: URL!


    override func setUpWithError() throws {
        try super.setUpWithError()
        dSYMPath = try prepareTempDir().appendingPathComponent("dsym")
        shell = { command, args, _, _ in
            self.shellCommands.append(ShellCall(command: command, args: args))
        }
    }

    override func tearDown() {
        shell = nil
        super.tearDown()
    }

    func testGeneratesDsymWhenWasntAlreadyProduced() throws {
        let expectedCommand = ShellCall(command: "dsymutil", args: [productURL.path, "-o", dSYMPath.path])
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .dynamicLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: false,
            fileManager: .default,
            shellCall: shell
        )

        let generatedDSYM = try organizer.relevantDSYMLocation()

        XCTAssertEqual(shellCommands, [expectedCommand])
        XCTAssertEqual(generatedDSYM, dSYMPath)
    }

    func testDoesntGenerateDsymWhenWasAlreadyProduced() throws {
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .dynamicLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: true,
            fileManager: .default,
            shellCall: shell
        )

        let generatedDSYM = try organizer.relevantDSYMLocation()

        XCTAssertEqual(shellCommands, [])
        XCTAssertEqual(generatedDSYM, dSYMPath)
    }

    func testCleanupHappensDeletesdSym() throws {
        fileManager.createFile(atPath: dSYMPath.path, contents: nil, attributes: nil)
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .dynamicLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: false,
            fileManager: .default,
            shellCall: shell
        )

        try organizer.cleanup()

        XCTAssertFalse(fileManager.fileExists(atPath: dSYMPath.path))
    }

    func testCleanupDoesntDeleteExternallyCreatedDsym() throws {
        fileManager.createFile(atPath: dSYMPath.path, contents: nil, attributes: nil)
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .dynamicLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: true,
            fileManager: .default,
            shellCall: shell
        )

        try organizer.cleanup()

        XCTAssertTrue(fileManager.fileExists(atPath: dSYMPath.path))
    }

    func testDoesntCreateDSymForStaticLib() throws {
        let organizer = DynamicDSYMOrganizer(
            productURL: productURL,
            machOType: .staticLib,
            dSYMPath: dSYMPath,
            wasDsymGenerated: false,
            fileManager: .default,
            shellCall: shell
        )

        XCTAssertNil(try organizer.relevantDSYMLocation())
    }
}
