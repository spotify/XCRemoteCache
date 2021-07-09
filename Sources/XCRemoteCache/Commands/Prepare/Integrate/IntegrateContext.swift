import Foundation

struct IntegrateContext {
    let projectPath: URL
    let repoRoot: URL
    let binaries: XCRCBinariesPaths
    let mode: Mode
    let configOverride: URL
    let fakeSrcRoot: URL
    let output: URL?
}

extension IntegrateContext {
    init(
        input: String,
        repoRootPath: String,
        mode: Mode,
        configOverridePath: String,
        env: [String: String],
        binariesDir: URL,
        fakeSrcRoot: String,
        outputPath: String?
    ) throws {
        projectPath = URL(fileURLWithPath: input)
        let srcRoot = projectPath.deletingLastPathComponent()
        repoRoot = URL(fileURLWithPath: repoRootPath, relativeTo: srcRoot)
        self.mode = mode
        configOverride = URL(fileURLWithPath: configOverridePath, relativeTo: srcRoot)
        output = outputPath.flatMap(URL.init(fileURLWithPath:))
        self.fakeSrcRoot = URL(fileURLWithPath: fakeSrcRoot)
        binaries = XCRCBinariesPaths(
            prepare: binariesDir.appendingPathComponent("xcprepare"),
            cc: binariesDir.appendingPathComponent("xccc"),
            swiftc: binariesDir.appendingPathComponent("xcswiftc"),
            libtool: binariesDir.appendingPathComponent("xclibtool"),
            ld: binariesDir.appendingPathComponent("xcld"),
            prebuild: binariesDir.appendingPathComponent("xcprebuild"),
            postbuild: binariesDir.appendingPathComponent("xcpostbuild")
        )
    }
}
