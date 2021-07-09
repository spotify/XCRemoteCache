import Foundation

enum DependenciesMapping {
    /// Specifies which ENVs should be rewritten in the dependencies generation to make generic (paths agnostics)
    /// list of dependencies
    static let rewrittenEnvs = ["BUILD_DIR", "SRCROOT"]
}
