import Foundation

/// Represents a mode that libtool was called
public enum XCLibtoolMode {
    /// Creating a static library (ar format) from a set of .o input files
    case createLibrary(output: String, filelist: String, dependencyInfo: String)
    /// Creating a universal library (multiple-architectures) from a set of input .a static libraries
    case createUniversalBinary(output: String, inputs: [String])
}

public class XCLibtool {
    private let logic: XCLibtoolLogic

    /// Intializer that depending on the argument mode, creates different libtool logic (kind of abstract factory)
    /// - Parameter mode: libtool mode to setup
    /// - Throws: XCLibtoolLogic specific errors if the mode arguments are invalid or inconsistent
    public init(_ mode: XCLibtoolMode) throws {
        switch mode {
        case .createLibrary(let output, let filelist, let dependencyInfo):
            logic = XCCreateBinary(
                output: output,
                filelist: filelist,
                dependencyInfo: dependencyInfo,
                fallbackCommand: "libtool",
                stepDescription: "Libtool"
            )
        case .createUniversalBinary(let output, let inputs):
            logic = try XCLibtoolCreateUniversalBinary(output: output, inputs: inputs)
        }
    }

    /// Executes the libtool logic
    public func run() {
        logic.run()
    }
}
