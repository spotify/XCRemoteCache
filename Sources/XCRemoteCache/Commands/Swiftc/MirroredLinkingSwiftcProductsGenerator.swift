import Foundation

enum MirroredLinkingSwiftcProductsGeneratorError: Error {
    /// When the generation source list misses a path to the main "swiftmodule" file
    case missingMainSwiftmoduleFileToGenerateFrom
}

/// Products generator that finds swift products destination based on the artifact dir structure. It uses
/// `LinkingSwiftcProductsGenerator` under the hood
///
/// Useful for cases where destination locations are not provided explicitly (e.g. in a thin projects)
class MirroredLinkingSwiftcProductsGenerator: SwiftcProductsGenerator {
    private let arch: String
    private let buildDir: URL
    private let headersDir: URL
    private let diskCopier: DiskCopier

    /// Default initializer
    /// - Parameters:
    ///   - arch: architecture of the build
    ///   - buildDir: directory where all *.swiftmodule products should be placed
    ///   - headersDir: directory where generated ObjC headers should be placed
    ///   - fileManager: fileManager instance
    init(
        arch: String,
        buildDir: URL,
        headersDir: URL,
        diskCopier: DiskCopier
    ) {
        self.arch = arch
        self.buildDir = buildDir
        self.headersDir = headersDir
        self.diskCopier = diskCopier
    }

    func generateFrom(
        artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> URL {
        /// Predict moduleName from the `*.swiftmodule` artifact
        let foundSwiftmoduleFile = artifactSwiftModuleFiles[.swiftmodule]
        guard let mainSwiftmoduleFile = foundSwiftmoduleFile else {
            throw MirroredLinkingSwiftcProductsGeneratorError.missingMainSwiftmoduleFileToGenerateFrom
        }
        let moduleName = mainSwiftmoduleFile.deletingPathExtension().lastPathComponent
        let modulePathOutput = buildDir
            .appendingPathComponent("\(moduleName).swiftmodule")
            .appendingPathComponent(arch)
            .appendingPathExtension("swiftmodule")
        let objcHeaderOutput = headersDir.appendingPathComponent("\(moduleName)-Swift.h")

        let generator = DiskSwiftcProductsGenerator(
            modulePathOutput: modulePathOutput,
            objcHeaderOutput: objcHeaderOutput,
            diskCopier: diskCopier
        )

        return try generator.generateFrom(
            artifactSwiftModuleFiles: artifactSwiftModuleFiles,
            artifactSwiftModuleObjCFile: artifactSwiftModuleObjCFile
        )
    }
}
