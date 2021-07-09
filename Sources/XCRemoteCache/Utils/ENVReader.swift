import Foundation

enum EnvironmentError: Error {
    case missingEnv(String)
}

extension Dictionary where Key == String, Value == String {
    func readEnv(key: String) throws -> URL {
        guard let value = self[key].map(URL.init(fileURLWithPath:)) else {
            throw EnvironmentError.missingEnv(key)
        }
        return value
    }

    func readEnv(key: String) -> String? {
        return self[key]
    }

    func readEnv(key: String) throws -> String {
        guard let value = self[key] else {
            throw EnvironmentError.missingEnv(key)
        }
        return value
    }

    func readEnv(key: String) throws -> Bool {
        guard let value = self[key] else {
            throw EnvironmentError.missingEnv(key)
        }
        return value == "YES"
    }
}
