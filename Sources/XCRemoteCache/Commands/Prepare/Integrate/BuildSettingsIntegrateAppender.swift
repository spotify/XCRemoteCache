import Foundation

typealias BuildSettings = [String: Any]

// Manages Xcode build settings
protocol BuildSettingsIntegrateAppender {
    /// Appends XCRemoteCache-specific build settings
    /// - Parameters:
    ///   - buildSettings: original build settings
    ///   - wrappers: definition of XCRemoteCache binaries location
    func appendToBuildSettings(buildSettings: BuildSettings, wrappers: XCRCBinariesPaths) -> BuildSettings
}

class XcodeProjBuildSettingsIntegrateAppender: BuildSettingsIntegrateAppender {
    private let mode: Mode
    private let repoRoot: URL

    init(mode: Mode, repoRoot: URL) {
        self.mode = mode
        self.repoRoot = repoRoot
    }

    func appendToBuildSettings(buildSettings: BuildSettings, wrappers: XCRCBinariesPaths) -> BuildSettings {
        var result = buildSettings
        result["SWIFT_EXEC"] = wrappers.swiftc.path
        // When generating artifacts, no need to shell-out all compilation commands to our wrappers
        if case .consumer = mode {
            result["CC"] = wrappers.cc.path
            result["LD"] = wrappers.ld.path
            result["LIBTOOL"] = wrappers.libtool.path
        }

        let existingSwiftFlags = result["OTHER_SWIFT_FLAGS"] as? String
        let existingCFlags = result["OTHER_CFLAGS"] as? String
        var swiftFlags = XcodeSettingsSwiftFlags(settingValue: existingSwiftFlags)
        var clangFlags = XcodeSettingsCFlags(settingValue: existingCFlags)

        // Overriding debug prefix map for Swift and ObjC to have consistent absolute path for all debug symbols
        swiftFlags.assignFlag(key: "debug-prefix-map", value: "\(repoRoot.path)=$(XCRC_FAKE_SRCROOT)")
        clangFlags.assignFlag(key: "debug-prefix-map", value: "\(repoRoot.path)=$(XCRC_FAKE_SRCROOT)")

        result["OTHER_SWIFT_FLAGS"] = swiftFlags.settingValue
        result["OTHER_CFLAGS"] = clangFlags.settingValue

        result["XCRC_FAKE_SRCROOT"] = "/\(String(repeating: "x", count: 10))"
        return result
    }
}
