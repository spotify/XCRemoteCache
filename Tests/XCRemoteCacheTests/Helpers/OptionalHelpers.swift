extension Optional {
    func unwrap() throws -> Wrapped {
        switch self {
        case .some(let value):
            return value
        default:
            throw "Unwrap failed"
        }
    }
}

extension String: Error {}
