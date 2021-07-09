import Foundation
import XCRemoteCache

/// Wrapper for a `LD` program that copies the dynamic executable from a cached-downloaded location
/// Fallbacks to a standard `clang` when the Ramote cache is not applicable (e.g. modified sources)
public class XCLDMain {
    public func main() {
        let args = ProcessInfo().arguments
        var output: String?
        var filelist: String?
        var dependencyInfo: String?
        var i = 0
        while i < args.count {
            switch args[i] {
            case "-o":
                output = args[i + 1]
                i += 1
            case "-filelist":
                filelist = args[i + 1]
                i += 1
            case "-dependency_info":
                // Skip following `-Xlinker` argument. Sample call:
                // `clang -dynamiclib  ... -Xlinker -dependency_info -Xlinker /path/Target_dependency_info.dat`
                dependencyInfo = args[i + 2]
                i += 2
            default:
                break
            }
            i += 1
        }
        guard let outputInput = output, let filelistInput = filelist, let dependencyInfoInput = dependencyInfo else {
            exit(1, "Missing 'output' argument. Args: \(args)")
        }


        // TODO: consider using `clang_command` from .rcinfo
        /// concrete clang path should be taken from the current toolchain
        let fallbackCommand = "clang"
        XCCreateBinary(
            output: outputInput,
            filelist: filelistInput,
            dependencyInfo: dependencyInfoInput,
            fallbackCommand: fallbackCommand,
            stepDescription: "xcld"
        ).run()
    }
}
