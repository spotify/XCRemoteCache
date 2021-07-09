@testable import XCRemoteCache
import XCTest

class XcodeSettingsCFlagsTests: XCTestCase {

    func testSettingFirstFlag() {
        var flags = XcodeSettingsCFlags(settingValue: nil)

        flags.assignFlag(key: "k", value: "v")

        XCTAssertEqual(flags.settingValue, "$(inherited) -fk=v")
    }

    func testSettingSecondFlag() {
        var flags = XcodeSettingsCFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: "v1")
        flags.assignFlag(key: "k2", value: "v2")

        XCTAssertEqual(flags.settingValue, "$(inherited) -fk1=v1 -fk2=v2")
    }

    func testOverridingFlag() {
        var flags = XcodeSettingsCFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: "v1")
        flags.assignFlag(key: "k1", value: "v2")

        XCTAssertEqual(flags.settingValue, "$(inherited) -fk1=v2")
    }

    func testDeletingFlag() {
        var flags = XcodeSettingsCFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: "v1")
        flags.assignFlag(key: "k1", value: nil)

        XCTAssertNil(flags.settingValue)
    }

    func testDeletingOnlySingleFlag() {
        var flags = XcodeSettingsCFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: "v1")
        flags.assignFlag(key: "k2", value: "v2")
        flags.assignFlag(key: "k1", value: nil)

        XCTAssertEqual(flags.settingValue, "$(inherited) -fk2=v2")
    }

    func testDeletingNonExistingFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: nil)

        XCTAssertNil(flags.settingValue)
    }

    func testAddingToCustomizedSetting() {
        var flags = XcodeSettingsCFlags(settingValue: "Customized")

        flags.assignFlag(key: "k1", value: "v1")

        XCTAssertEqual(flags.settingValue, "Customized -fk1=v1")
    }

    func testOverridingCustomizedFlag() {
        var flags = XcodeSettingsCFlags(settingValue: "-fk1=v1")

        flags.assignFlag(key: "k1", value: "v2")

        XCTAssertEqual(flags.settingValue, "-fk1=v2")
    }

    func testDeletingCustomizedFlag() {
        var flags = XcodeSettingsCFlags(settingValue: "-fk1=v1")

        flags.assignFlag(key: "k1", value: nil)

        XCTAssertEqual(flags.settingValue, "")
    }

    func testDeletingLastCustomizedFlag() {
        var flags = XcodeSettingsCFlags(settingValue: "$(inherited) -fk1=v1")

        flags.assignFlag(key: "k1", value: nil)

        XCTAssertNil(flags.settingValue)
    }
}
