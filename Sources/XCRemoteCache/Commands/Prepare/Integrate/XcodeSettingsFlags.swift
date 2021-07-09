import Foundation

/// Type to manage Xcode build setting with compilation flags (e.g. OTHER_CFLAGS or OTHER_SWIFT_FLAGS)
public protocol XcodeSettingsFlags {
    var settingValue: String? { get }

    mutating func assignFlag(key: String, value: String?)
}

/// Builds compilation flags string value
private struct XcodeSettingsBuilder {
    static let inheritedExpression: String = "$(inherited)"

    static func composeFlags(_ flags: [String]) -> String? {
        if flags == [Self.inheritedExpression] {
            return nil
        }
        return flags.joined(separator: " ")
    }
}

/// Manages flags for OTHER_SWIFT_FLAGS Xcode's Build Setting
struct XcodeSettingsSwiftFlags: XcodeSettingsFlags {
    private static let swiftFlagPrefix = "-"

    private(set) var settingValue: String?

    init(settingValue: String?) {
        self.settingValue = settingValue
    }

    private func buildSwiftFlag(key: String, value: String) -> [String] {
        [key, value]
    }

    mutating func assignFlag(key: String, value: String?) {
        let flags: [String]
        let formattedKey = Self.swiftFlagPrefix.appending(key)
        switch (settingValue, value) {
        case (nil, nil):
            return
        case (nil, .some(let value)):
            flags = [XcodeSettingsBuilder.inheritedExpression, formattedKey, value]
        case (.some(let existing), _):
            var flagsComponents: [String] = existing.split(separator: " ").map(String.init)
            // remove (if exists)
            if let previousIndex = flagsComponents.firstIndex(of: formattedKey) {
                // delete "-{key}" and "{value}"
                flagsComponents.removeSubrange(previousIndex..<previousIndex + 2)
            }
            // add if setting a non nil value
            if let newValue = value {
                flagsComponents += buildSwiftFlag(key: formattedKey, value: newValue)
            }
            flags = flagsComponents
        }
        settingValue = XcodeSettingsBuilder.composeFlags(flags)
    }
}

/// Manages flags for OTHER_CFLAGS Xcode's Build Setting
struct XcodeSettingsCFlags: XcodeSettingsFlags {
    private static let prefix = "-f"
    private(set) var settingValue: String?

    init(settingValue: String?) {
        self.settingValue = settingValue
    }

    private func buildCFlag(key: String, value: String) -> [String] {
        ["\(Self.prefix)\(key)=\(value)"]
    }

    mutating func assignFlag(key: String, value: String?) {
        let flags: [String]
        switch (settingValue, value) {
        case (nil, nil):
            return
        case (nil, .some(let value)):
            flags = [XcodeSettingsBuilder.inheritedExpression] + buildCFlag(key: key, value: value)
        case (.some(let existing), _):
            var flagsComponents: [String] = existing.split(separator: " ").map(String.init)
            // remove (if exists)
            let existingFlagIndex = flagsComponents.firstIndex { (component) -> Bool in
                component.hasPrefix("\(Self.prefix)\(key)=")
            }
            if let index = existingFlagIndex {
                flagsComponents.remove(at: index)
            }
            // add (if sets new)
            if let newValue = value {
                flagsComponents += buildCFlag(key: key, value: newValue)
            }
            flags = flagsComponents
        }
        settingValue = XcodeSettingsBuilder.composeFlags(flags)
    }
}
