import Foundation

public struct SwiftcContext {
    enum SwiftcMode: Equatable {
        case producer
        /// Commit sha of the commit to use during remote cache
        case consumer(commit: RemoteCommitInfo)
    }

    let objcHeaderOutput: URL
    let moduleName: String
    let modulePathOutput: URL
    /// File that defines output files locations (.d, .swiftmodule etc.)
    let filemap: URL
    let target: String
    /// File that contains input files for the swift module compilation
    let fileList: URL
    let tempDir: URL
    let arch: String
    let prebuildDependenciesPath: String
    let mode: SwiftcMode
    /// File that stores all compilation invocation arguments
    let invocationHistoryFile: URL


    public init(
        config: XCRemoteCacheConfig,
        objcHeaderOutput: String,
        moduleName: String,
        modulePathOutput: String,
        filemap: String,
        target: String,
        fileList: String
    ) throws {
        self.objcHeaderOutput = URL(fileURLWithPath: objcHeaderOutput)
        self.moduleName = moduleName
        self.modulePathOutput = URL(fileURLWithPath: modulePathOutput)
        self.filemap = URL(fileURLWithPath: filemap)
        self.target = target
        self.fileList = URL(fileURLWithPath: fileList)
        // modulePathOutput is place in $TARGET_TEMP_DIR/Objects-normal/$ARCH/$TARGET_NAME.swiftmodule
        // That may be subject to change for other Xcode versions
        tempDir = URL(fileURLWithPath: modulePathOutput)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        arch = URL(fileURLWithPath: modulePathOutput).deletingLastPathComponent().lastPathComponent

        let srcRoot: URL = URL(fileURLWithPath: config.sourceRoot)
        let remoteCommitLocation = URL(fileURLWithPath: config.remoteCommitFile, relativeTo: srcRoot)
        prebuildDependenciesPath = config.prebuildDiscoveryPath
        switch config.mode {
        case .consumer:
            let remoteCommit = RemoteCommitInfo(try? String(contentsOf: remoteCommitLocation).trim())
            mode = .consumer(commit: remoteCommit)
        case .producer:
            mode = .producer
        }
        invocationHistoryFile = URL(fileURLWithPath: config.compilationHistoryFile, relativeTo: tempDir)
    }

    init(
        config: XCRemoteCacheConfig,
        input: SwiftcArgInput
    ) throws {
        try self.init(
            config: config,
            objcHeaderOutput: input.objcHeaderOutput,
            moduleName: input.moduleName,
            modulePathOutput: input.modulePathOutput,
            filemap: input.filemap,
            target: input.target,
            fileList: input.fileList
        )
    }
}
