import Foundation

enum DiskSwiftcProductsGeneratorError: Error {
    /// When a generator was asked to generate unknown swiftmodule extension file.
    /// Probably a programmer error: asking to generate excessive extensions, not listed in
    /// `SwiftmoduleFileExtension.SwiftmoduleExtensions`
    case unknownSwiftmoduleFile
}

/// Generates swiftc product to the expected location
protocol SwiftcProductsGenerator {
    /// Generates products from given files
    /// - Returns: location dir where .swiftmodule files have been placed
    func generateFrom(
        artifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> URL
}

/// Generator that produces all products in the locations where Xcode expects it, using provided disk copier
class DiskSwiftcProductsGenerator: SwiftcProductsGenerator {
    private let destinationSwiftmodulePaths: [SwiftmoduleFileExtension: URL]
    private let modulePathOutput: URL
    private let objcHeaderOutput: URL
    private let diskCopier: DiskCopier

    init(
        modulePathOutput: URL,
        objcHeaderOutput: URL,
        diskCopier: DiskCopier
    ) {
        self.modulePathOutput = modulePathOutput
        let modulePathBasename = modulePathOutput.deletingPathExtension()
        // all swiftmodule-related should be located next to the ".swiftmodule"
        destinationSwiftmodulePaths = Dictionary(
            uniqueKeysWithValues: SwiftmoduleFileExtension.SwiftmoduleExtensions
                .map { ext, _ in
                    (ext, modulePathBasename.appendingPathExtension(ext.rawValue))
                }
        )
        self.objcHeaderOutput = objcHeaderOutput
        self.diskCopier = diskCopier
    }

    func generateFrom(
        artifactSwiftModuleFiles sourceAtifactSwiftModuleFiles: [SwiftmoduleFileExtension: URL],
        artifactSwiftModuleObjCFile: URL
    ) throws -> URL {
        // Move cached -Swift.h file to the expected location
        try diskCopier.copy(file: artifactSwiftModuleObjCFile, destination: objcHeaderOutput)
        for (ext, url) in sourceAtifactSwiftModuleFiles {
            let dest = destinationSwiftmodulePaths[ext]
            guard let destination = dest else {
                throw DiskSwiftcProductsGeneratorError.unknownSwiftmoduleFile
            }
            do {
                // Move cached .swiftmodule to the expected location
                try diskCopier.copy(file: url, destination: destination)
            } catch {
                if case .required = SwiftmoduleFileExtension.SwiftmoduleExtensions[ext] {
                    throw error
                } else {
                    infoLog("Optional .\(ext) file not found in the artifact at: \(destination.path)")
                }
            }
        }

        // Build parent dir of the .swiftmodule file that contains a module
        return modulePathOutput.deletingLastPathComponent()
    }
}
