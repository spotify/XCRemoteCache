@testable import XCRemoteCache
import XCTest

class XcodeSettingsSwiftFlagsSetterTests: XCTestCase {

    func testSettingFirstFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: nil)

        flags.assignFlag(key: "k", value: "v")

        XCTAssertEqual(flags.settingValue, "$(inherited) -k v")
    }

    func testSettingSecondFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: "v1")
        flags.assignFlag(key: "k2", value: "v2")

        XCTAssertEqual(flags.settingValue, "$(inherited) -k1 v1 -k2 v2")
    }

    func testOverridingFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: "v1")
        flags.assignFlag(key: "k1", value: "v2")

        XCTAssertEqual(flags.settingValue, "$(inherited) -k1 v2")
    }

    func testDeletingFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: "v1")
        flags.assignFlag(key: "k1", value: nil)

        XCTAssertNil(flags.settingValue)
    }

    func testDeletingOnlySingleFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: "v1")
        flags.assignFlag(key: "k2", value: "v2")
        flags.assignFlag(key: "k1", value: nil)

        XCTAssertEqual(flags.settingValue, "$(inherited) -k2 v2")
    }

    func testDeletingNonExistingFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: nil)

        flags.assignFlag(key: "k1", value: nil)

        XCTAssertNil(flags.settingValue)
    }

    func testAddingToCustomizedSetting() {
        var flags = XcodeSettingsSwiftFlags(settingValue: "Customized")

        flags.assignFlag(key: "k1", value: "v1")

        XCTAssertEqual(flags.settingValue, "Customized -k1 v1")
    }

    func testOverridingCustomizedFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: "-k1 v1")

        flags.assignFlag(key: "k1", value: "v2")

        XCTAssertEqual(flags.settingValue, "-k1 v2")
    }

    func testDeletingCustomizedFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: "-k1 v1")

        flags.assignFlag(key: "k1", value: nil)

        XCTAssertEqual(flags.settingValue, "")
    }

    func testDeletingLastCustomizedFlag() {
        var flags = XcodeSettingsSwiftFlags(settingValue: "$(inherited) -k1 v1")

        flags.assignFlag(key: "k1", value: nil)

        XCTAssertNil(flags.settingValue)
    }
}
