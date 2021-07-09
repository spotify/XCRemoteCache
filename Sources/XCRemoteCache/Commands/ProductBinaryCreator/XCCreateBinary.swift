import Foundation

/// Wrapper for `libtool` or `ld` call for creating a binary (a static or a dynamic library)
/// Moves binary from a cache aritfact to the output location or
/// fallbacks to the standard command (when cached product is not applicable)
public class XCCreateBinary {
    private let output: URL
    private let tempDir: URL
    private let dependencyInfo: URL
    private let fallbackCommand: String
    private let stepDescription: String

    /// Initializer of a binary creator step
    /// - Parameters:
    ///   - output: Destination of the binary to create
    ///   - filelist: location of a filelist file with all input files of that step
    ///   - dependencyInfo: location of the file to specify all dependencies of that step
    ///   - fallbackCommand: command of the fallback command
    ///   - stepDescription: descriptive name of the step
    public init(
        output: String,
        filelist: String,
        dependencyInfo: String,
        fallbackCommand: String,
        stepDescription: String
    ) {
        self.output = URL(fileURLWithPath: output)
        self.dependencyInfo = URL(fileURLWithPath: dependencyInfo)
        // fileList is place in $TARGET_TEMP_DIR/Objects-normal/$ARCH/$TARGET_NAME.LinkFileList
        // TODO: find better (stable) technique to determine `$TARGET_TEMP_DIR`
        tempDir = URL(fileURLWithPath: filelist)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        self.fallbackCommand = fallbackCommand
        self.stepDescription = stepDescription
    }

    private func fallbackToDefault() -> Never {
        let args = ProcessInfo().arguments
        let paramList = [fallbackCommand] + args.dropFirst()
        let cargs = paramList.map { strdup($0) } + [nil]
        execvp(fallbackCommand, cargs)

        /// C-function `execv` returns only when the command fails
        exit(1)
    }

    public func run() {
        let fileManager = FileManager.default
        let config: XCRemoteCacheConfig
        do {
            let srcRoot: URL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            config = try XCRemoteCacheConfigReader(srcRootPath: srcRoot.path, fileManager: fileManager)
                .readConfiguration()
        } catch {
            errorLog("\(stepDescription) initialization failed with error: \(error). Fallbacking to \(fallbackCommand)")
            fallbackToDefault()
        }
        let markerURL = tempDir.appendingPathComponent(config.modeMarkerPath)
        do {
            let organizer = ZipArtifactOrganizer(targetTempDir: tempDir, fileManager: fileManager)
            let dependenciesWriter = FileDatWriter(dependencyInfo, fileManager: fileManager)
            let markerReader = FileMarkerReader(markerURL, fileManager: fileManager)
            guard fileManager.fileExists(atPath: markerURL.path) else {
                fallbackToDefault()
            }

            let cachedArtifactDir = organizer.getActiveArtifactLocation()
            let outputFilename = output.lastPathComponent
            let cachedBinaryURL = cachedArtifactDir.appendingPathComponent(outputFilename)
            try fileManager.spt_forceLinkItem(at: cachedBinaryURL, to: output)
            try dependenciesWriter.enable(dependencies: markerReader.listFilesURLs(), outputs: [output])
        } catch {
            errorLog("\(stepDescription) failed with error: \(error). Fallbacking to \(fallbackCommand)")
            do {
                try fileManager.removeItem(at: markerURL)
                fallbackToDefault()
            } catch {
                exit(1, "FATAL: \(stepDescription) failed with error: \(error)")
            }
        }
    }
}
