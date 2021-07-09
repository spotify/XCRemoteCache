import Foundation

/// Locally generated artifact
struct Artifact {
    /// Unique identifier of an artifact
    let id: String
    /// Location of the generated artifact package
    let package: URL
    /// Location of the generated meta file
    let meta: URL
}

/// Creates a local artifact that contains all products generated in the building process
protocol ArtifactCreator {
    func createArtifact(artifactKey: String, meta: MainArtifactMeta) throws -> Artifact
}

class BuildArtifactCreator: ArtifactSwiftProductsBuilderImpl, ArtifactCreator {
    private let buildDir: URL
    private let tempDir: URL
    private let executablePath: String
    private let moduleName: String?
    private let modulesFolderPath: String
    private let dSYMPath: URL
    private let fileManager: FileManager

    init(
        buildDir: URL,
        tempDir: URL,
        executablePath: String,
        moduleName: String?,
        modulesFolderPath: String,
        dSYMPath: URL,
        fileManager: FileManager
    ) {
        self.buildDir = buildDir
        self.modulesFolderPath = modulesFolderPath
        self.tempDir = tempDir
        self.executablePath = executablePath
        self.moduleName = moduleName
        self.fileManager = fileManager
        self.dSYMPath = dSYMPath
        super.init(workingDir: tempDir, moduleName: moduleName, fileManager: fileManager)
    }

    func createArtifact(artifactKey: String, meta: MainArtifactMeta) throws -> Artifact {
        let zipWorkingDir = buildingArtifactLocation()

        let binary = buildDir.appendingPathComponent(executablePath)
        var zipPaths = [binary]
        let swiftArtifacts = try prepareSwiftArtifacts(tempDir: zipWorkingDir)
        zipPaths.append(contentsOf: swiftArtifacts)
        let dynamicLibraryArtifacts = try prepareDynamicLibraryArtifacts()
        zipPaths.append(contentsOf: dynamicLibraryArtifacts)

        let creator = ZipArtifactCreator(workingDir: zipWorkingDir, fileManager: fileManager)
        return try creator.createArtifact(zipContent: zipPaths, artifactKey: artifactKey, meta: meta)
    }

    /// Prepare optional swift products: .swiftmodule, .swiftdoc, -Swift.h
    /// - Parameter tempDir: Temp location to organize file hierarchy in the artifact
    /// - returns: URLs to include into the artifact package
    fileprivate func prepareSwiftArtifacts(tempDir: URL) throws -> [URL] {
        var artifacts: [URL] = []

        // Add optional directory with generated ObjC headers
        let generatedObjCURL = buildingArtifactObjCHeadersLocation()
        if fileManager.fileExists(atPath: generatedObjCURL.path) {
            artifacts.append(generatedObjCURL)
        }

        // Add optional directory with generated .swiftmodule files
        let generatedSwiftModuleURL = buildingArtifactSwiftModulesLocation()
        if fileManager.fileExists(atPath: generatedSwiftModuleURL.path) {
            artifacts.append(generatedSwiftModuleURL)
        }
        return artifacts
    }

    /// Returns a list of extra files to bundle, related to the dynamic library (if present)
    fileprivate func prepareDynamicLibraryArtifacts() throws -> [URL] {
        if fileManager.fileExists(atPath: dSYMPath.path) {
            return [dSYMPath]
        }
        return []
    }
}
