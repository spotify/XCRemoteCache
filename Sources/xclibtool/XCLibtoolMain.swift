import Foundation
import XCRemoteCache

/// Wrapper for a `libtool` program that copies the build executable (e.g. .a) from a cached-downloaded location
/// Fallbacks to a standard `libtool` when the Ramote cache is not applicable (e.g. modified sources)
public class XCLibtoolMain {
    public func main() {
        let args = ProcessInfo().arguments
        var output: String?
        // all input arguments library '.a'. Used to create an universal binary
        var inputLibraries: [String] = []
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
                dependencyInfo = args[i + 1]
                i += 1
            case let input where input.hasSuffix(".a"):
                inputLibraries.append(input)
            default:
                break
            }
            i += 1
        }
        guard let outputInput = output else {
            exit(1, "Missing 'output' argument. Args: \(args)")
        }

        let mode: XCLibtoolMode
        if let filelistInput = filelist, let dependencyInfoInput = dependencyInfo {
            // libtool is creating a library
            mode = .createLibrary(output: outputInput, filelist: filelistInput, dependencyInfo: dependencyInfoInput)
        } else if !inputLibraries.isEmpty {
            // multiple input libraries suggest creating an universal binary
            mode = .createUniversalBinary(output: outputInput, inputs: inputLibraries)
        } else {
            // unknown mode
            exit(1, "Unsupported mode. Args: \(args)")
        }
        do {
            try XCLibtool(mode).run()
        } catch {
            exit(1, "Failed with: \(error). Args: \(args)")
        }
    }
}
