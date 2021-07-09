import Foundation

/// Representing locations of all XCRemoteCache binaries (including wrappers and phase scripts)
struct XCRCBinariesPaths {
    let prepare: URL
    let cc: URL
    let swiftc: URL
    let libtool: URL
    let ld: URL
    let prebuild: URL
    let postbuild: URL
}
