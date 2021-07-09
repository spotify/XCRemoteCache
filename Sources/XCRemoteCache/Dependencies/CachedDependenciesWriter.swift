import Foundation

/// Performant DependenciesWriter manager that reuses generated dependencies file
/// between multiple files that produce the same dependencies
/// This class is not thread-safe
class CachedFileDependenciesWriterFactory {
    private let dependencies: [URL]
    private let fileManager: FileManager
    private let factory: (URL, FileManager) -> DependenciesWriter
    private var templateDependencyFile: URL?

    init(
        dependencies: [URL],
        fileManager: FileManager,
        writerFactory: @escaping (URL, FileManager) -> DependenciesWriter
    ) {
        self.dependencies = dependencies
        self.fileManager = fileManager
        factory = writerFactory
    }

    func generate(output: URL) throws {
        if let template = templateDependencyFile {
            try fileManager.spt_forceCopyItem(at: template, to: output)
            return
        }
        // Generate the template file (happens only once)
        let writer = factory(output, fileManager)
        try writer.writeGeneric(dependencies: dependencies)
        if fileManager.fileExists(atPath: output.path) {
            // the file has been correctly created
            templateDependencyFile = output
        }
    }
}
