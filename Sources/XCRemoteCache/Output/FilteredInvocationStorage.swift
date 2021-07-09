/// Filters retrieved invocations
struct FilteredInvocationStorage: InvocationStorage {
    /// Underlying storage
    let storage: InvocationStorage
    /// List of commands that shouldn't be returned from the `retrieveAll`
    let retrieveIgnoredCommands: [String]

    func store(args: [String]) throws {
        try storage.store(args: args)
    }

    func retrieveAll() throws -> [[String]] {
        let allInvocations = try storage.retrieveAll()
        return try allInvocations.filter { invocation in
            guard let command = invocation.first else {
                throw InvocationStorageError.corruptedStorage
            }
            return !retrieveIgnoredCommands.contains(command)
        }
    }
}
