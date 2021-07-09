import Foundation

enum FileAccessorError: Error {
    /// Failed to open a file using `open`
    case openingFailure
    /// Counldn't acquire a lock
    case lockingFailure
    /// A file has been deleted while waiting for a lock
    case fileDeleted
}

/// Access the file with the exclusive lock acquired
protocol ExclusiveFileAccessor {
    /// Opens a file (or creates if not existing) and acquires an exclusive lock
    /// - Parameter block: action to perform on a file with the exclusive lock access
    /// - Returns: passes the value that the block returned
    /// - Throws: `FileAccessorError` instance
    func exclusiveAccess<T>(block: (FileHandle) throws -> (T)) throws -> T
}


/// Represents a file with the exclusive access
class ExclusiveFile: ExclusiveFileAccessor {
    enum Mode {
        case override
        case append
    }

    private var fileURL: URL
    /// `open` flags to represent a mode
    private var extraFlags: Int32

    init(_ fileURL: URL, mode: Mode, createOnNeed: Bool = true) {
        self.fileURL = fileURL
        switch mode {
        case .override: extraFlags = 0
        case .append: extraFlags = O_APPEND
        }
        if createOnNeed {
            extraFlags |= O_CREAT
        }
    }

    func exclusiveAccess<T>(block: (FileHandle) throws -> (T)) throws -> T {
        // Read, write
        // mode (if the file is not existing: 0x444)
        let chmod = S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH
        let fd = open(fileURL.path, extraFlags | O_RDWR, chmod)
        guard fd > 0 else {
            throw FileAccessorError.openingFailure
        }
        let handle = FileHandle(fileDescriptor: fd)
        defer {
            // closing releases a lock form `flock` (if is set)
            handle.closeFile()
        }
        guard flock(fd, LOCK_EX) == 0 else {
            throw FileAccessorError.lockingFailure
        }
        // While having a lock, make sure the file still exists.
        // It might delete it while we were waiting for a lock.
        guard access(fileURL.path, F_OK) == 0 else {
            throw FileAccessorError.lockingFailure
        }

        return try block(handle)
    }
}
