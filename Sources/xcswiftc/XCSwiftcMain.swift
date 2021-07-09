import Foundation
import XCRemoteCache

/// Wrapper for a `swiftc` that skips compilation and produces empty output files (.o). As a compilation dependencies
/// (.d) file, it copies all dependency files from the prebuild marker file
/// Fallbacks to a standard `swiftc` when the Ramote cache is not applicable (e.g. modified sources)
public class XCSwiftcMain {
    // swiftlint:disable:next function_body_length
    public func main() {
        let command = ProcessInfo().processName
        let args = ProcessInfo().arguments
        var objcHeaderOutput: String?
        var moduleName: String?
        var modulePathOutput: String?
        var filemap: String?
        var target: String?
        var swiftFileList: String?
        for i in 0..<args.count {
            let arg = args[i]
            switch arg {
            case "-emit-objc-header-path":
                objcHeaderOutput = args[i + 1]
            case "-module-name":
                moduleName = args[i + 1]
            case "-emit-module-path":
                modulePathOutput = args[i + 1]
            case "-output-file-map":
                filemap = args[i + 1]
            case "-target":
                target = args[i + 1]
            default:
                if arg.hasPrefix("@") && arg.hasSuffix(".SwiftFileList") {
                    swiftFileList = String(arg.dropFirst())
                }
            }
        }
        guard let objcHeaderOutputInput = objcHeaderOutput,
            let moduleNameInput = moduleName,
            let modulePathOutputInput = modulePathOutput,
            let filemapInput = filemap,
            let targetInputInput = target,
            let swiftFileListInput = swiftFileList
            else {
                print("Missing argument. Args: \(args)")
                exit(1)
        }
        let swiftcArgsInput = SwiftcArgInput(
            objcHeaderOutput: objcHeaderOutputInput,
            moduleName: moduleNameInput,
            modulePathOutput: modulePathOutputInput,
            filemap: filemapInput,
            target: targetInputInput,
            fileList: swiftFileListInput
        )
        XCSwiftc(
            command: command,
            inputArgs: swiftcArgsInput,
            dependenciesWriter: FileDependenciesWriter.init,
            touchFactory: FileTouch.init
        ).run()
    }
}
