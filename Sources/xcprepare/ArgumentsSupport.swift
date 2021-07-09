import ArgumentParser
import XCRemoteCache

extension XCOutputFormat: ExpressibleByArgument {
    public init?(argument: String) {
        switch argument {
        case "json":
            self = .json
        case "yaml":
            self = .yaml
        default:
            return nil
        }
    }
}
