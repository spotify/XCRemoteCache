import Foundation

// Recognizes
protocol SwiftProductsArchitecturesRecognizer {
    /// Scans Product dir to find which final archs Xcode generated for a target
    /// Sample architecture list: ["x86_64", "x86_64-apple-ios-simulator"]
    /// - Parameters:
    ///   - builtProductsDir: Location of the bulilt products dir to inspect - $(BUILT_PRODUCTS_DIR)
    ///   - moduleName: a name of the module to inspect
    /// - Returns: list of architectures
    func recognizeArchitectures(builtProductsDir: URL, moduleName: String) throws -> [String]
}

class DefaultSwiftProductsArchitecturesRecognizer: SwiftProductsArchitecturesRecognizer {
    /// Extension of a directory that contains all swift{module|doc|...} files
    private static let SwiftmoduleDirExtension = "swiftmodule"
    private let dirAccessor: DirAccessor

    init(dirAccessor: DirAccessor) {
        self.dirAccessor = dirAccessor
    }

    func recognizeArchitectures(builtProductsDir: URL, moduleName: String) throws -> [String] {
        /// Location where Xcode puts all swiftmodules
        let moduleDirectory = builtProductsDir
            .appendingPathComponent(moduleName)
            .appendingPathExtension(Self.SwiftmoduleDirExtension)
        let productFiles = try dirAccessor.items(at: moduleDirectory)
        /// files in a moduleDirectory have basename corresponding to the
        /// architecture (e.g. 'x86_64-apple-ios-simulator.swiftmodule', 'x86_64.swiftmodule' ...)
        let architectures = productFiles.map { file -> String in
            // recursively delete extensions to get rid of potential fingerprint overrides in a product directory
            var basenameFile = file
            while !basenameFile.pathExtension.isEmpty {
                basenameFile.deletePathExtension()
            }
            return basenameFile.lastPathComponent
        }
        // remove duplicates comming from files with different extensions (swiftmodule, swiftdoc etc.)
        return Set(architectures).sorted()
    }
}
