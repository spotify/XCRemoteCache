import Foundation

enum InvocationStorageError: Error {
    /// The invocation entry is not valid. Potentially corrupted storage or adding an illegal entry to the storage
    case corruptedStorage
}

/// Command invocations storage
protocol InvocationStorage {
    /// Adds new entry with invocation arguments
    /// - Parameter args: arguments of the invocations
    func store(args: [String]) throws

    /// Reads all stored invocations and destroys a storage
    /// - Returns an array of invocations that contain an array or the command and args
    func retrieveAll() throws -> [[String]]
}

/// Saves all invocations to an existing local file
class ExistingFileStorage: InvocationStorage {

    private let command: String
    private let storageFile: URL
    private let exclusiveFile: ExclusiveFileAccessor

    private static let encoding = String.Encoding.utf8
    private static let ArgsSeparatorByte: UInt8 = 0 // `\0`
    private static let ArgsSeparator: Data = Data([ArgsSeparatorByte])
    private static let CommandsSeparatorByte: UInt8 = 10 // '\n`
    private static let CommandsSeparator = Data([ArgsSeparatorByte, CommandsSeparatorByte])


    init(storageFile: URL, command: String) {
        self.command = command
        self.storageFile = storageFile
        // xcswiftc and xccc shouldn't create a storage. It should be created only by xcprebuild
        exclusiveFile = ExclusiveFile(storageFile, mode: .append, createOnNeed: false)
    }

    func store(args: [String]) throws {

        // Save data in a format of `command\0arg1\0arg2\0\0\n`
        var data = command.data(using: Self.encoding)!
        data.append(Self.ArgsSeparator)
        for arg in args {
            data.append(arg.data(using: Self.encoding)!)
            data.append(Self.ArgsSeparator)
        }
        data.append(Self.CommandsSeparator)

        // Once the data is ready, append it to the file in the exclusive access block for better performance
        try exclusiveFile.exclusiveAccess { file in
            file.write(data)
        }
    }

    func retrieveAll() throws -> [[String]] {
        let allData: Data = try exclusiveFile.exclusiveAccess { file in
            let data = file.availableData
            // Clear the file, while still keeping a lock
            // No need to verify it it succeeded:
            // some other process may already delete it and that
            // wouldn't affect our flow
            remove(storageFile.path)
            return data
        }
        let allInvocations = allData.split(separator: Self.CommandsSeparatorByte)
        return allInvocations.map { invocationData in
            let argsData = invocationData.split(separator: Self.ArgsSeparatorByte)
            return argsData.map {
                String(bytes: $0, encoding: .utf8)!
            }
        }
    }
}
