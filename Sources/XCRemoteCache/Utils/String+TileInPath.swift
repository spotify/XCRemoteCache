import Foundation

extension String {
    /// Replacement of NSString's `expandingTildeInPath` where `~` is replaced with a local home address
    /// - Returns: A string that resolves `~` character to $HOME
    var expandingTildeInPath: String {
        replacingOccurrences(of: "~", with: NSHomeDirectory())
    }
}
