import Foundation

enum SwiftmoduleFileExtensionType {
    case required
    case optional
}

// Type of the file that constitutes a full modulemap package
// RawValue corresponds to the file extension
enum SwiftmoduleFileExtension: String {
    case swiftmodule
    case swiftdoc
    case swiftsourceinfo
}

extension SwiftmoduleFileExtension {
    /// List of all swiftmodule extensions that should be copied to the artifact
    static let SwiftmoduleExtensions: [SwiftmoduleFileExtension: SwiftmoduleFileExtensionType] = [
        .swiftmodule: .required,
        .swiftdoc: .required,
        .swiftsourceinfo: .optional,
    ]
}
