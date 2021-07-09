import Foundation

/// Replaces paths formats between generic (placeholders-based) and local
protocol DependenciesRemapper {
    /// Replaces all generic paths (with placeholders) to a local paths
    func replace(genericPaths: [String]) -> [String]
    /// Replaces all local paths to the generic dependencies paths
    func replace(localPaths: [String]) -> [String]
}

class DependenciesRemapperComposite: DependenciesRemapper {
    private let remappers: [DependenciesRemapper]

    init(_ remappers: [DependenciesRemapper]) {
        self.remappers = remappers
    }

    func replace(genericPaths: [String]) -> [String] {
        remappers.reduce(genericPaths) { prev, mapper in
            mapper.replace(genericPaths: prev)
        }
    }

    func replace(localPaths: [String]) -> [String] {
        remappers.reduce(localPaths) { prev, mapper in
            mapper.replace(localPaths: prev)
        }
    }
}

final class StringDependenciesRemapper: DependenciesRemapper {
    struct Mapping {
        let generic: String
        let local: String
    }

    private let mappings: [Mapping]

    init(mappings: [Mapping]) {
        self.mappings = mappings
    }

    func replace(genericPaths: [String]) -> [String] {
        return genericPaths.map { path in
            let localPath = mappings.reduce(path) { prevPath, mapping in
                prevPath.replacingOccurrences(of: mapping.generic, with: mapping.local)
            }
            return localPath
        }
    }

    func replace(localPaths: [String]) -> [String] {
        return localPaths.map { path in
            let result = mappings.reduce(path) { prevPath, mapping in
                prevPath.replacingOccurrences(of: mapping.local, with: mapping.generic)
            }
            return result
        }
    }
}


extension StringDependenciesRemapper {
    static func buildFromEnvs(keys: [String], envs: [String: String]) throws -> Self {
        let mappings: [Mapping] = try keys.map { key in
            let localValue: String = try envs.readEnv(key: key)
            return Mapping(generic: "$(\(key))", local: localValue)
        }
        return Self(mappings: mappings)
    }
}
