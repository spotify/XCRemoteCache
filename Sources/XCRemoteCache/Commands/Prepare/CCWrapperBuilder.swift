import Foundation

/// Builds a cc (clang) command wrapper that noops when cached artifact is used
protocol CCWrapperBuilder {
    /// Compiles CC wrapper and places output binary in a destination location
    /// - Parameters:
    ///   - destination: output location of the binary
    ///   - commitSha: remote commit sha that is currently in use
    func compile(to destination: URL, commitSha: String) throws
}

// swiftlint:disable:next type_body_length
class TemplateBasedCCWrapperBuilder: CCWrapperBuilder {
    private static let AppleGenericVersioningSuffix = "_vers.c"
    private let clangCommand: String
    private let markerPath: String
    private let cachedTargetMockFilename: String
    private let prebuildDFilename: String
    private let compilationHistoryFilename: String
    private let shell: ShellOutFunction
    private let fileManager: FileManager

    init(
        clangCommand: String,
        markerPath: String,
        cachedTargetMockFilename: String,
        prebuildDFilename: String,
        compilationHistoryFilename: String,
        shellOut: @escaping ShellOutFunction,
        fileManager: FileManager
    ) {
        self.clangCommand = clangCommand
        self.markerPath = markerPath
        self.cachedTargetMockFilename = cachedTargetMockFilename
        self.prebuildDFilename = prebuildDFilename
        self.compilationHistoryFilename = compilationHistoryFilename
        shell = shellOut
        self.fileManager = fileManager
    }

    /// Compiles xccc app and places binary in the destination location
    func compile(to destination: URL, commitSha: String) throws {
        let compilationFile = fileManager.temporaryDirectory.appendingPathComponent("xccc.c")
        let compilationContent = buildWrapperSource(
            clangCommand: clangCommand,
            markerFilename: markerPath,
            commitSha: commitSha
        )
        fileManager.createFile(
            atPath: compilationFile.path,
            contents: compilationContent.data(using: .utf8),
            attributes: nil
        )
        infoLog("ClangWrapperBuilder compiles file at \(compilationFile).")
        // -O3: optimize for faster execution
        let args = [clangCommand, "-O3", compilationFile.path, "-o", destination.path]
        let compilationOutput = try shell("xcrun", args, URL(fileURLWithPath: "").path, nil)
        infoLog("Clang compilation output: \(compilationOutput)")
    }


    /// Generates source of the cc wrapper
    // swiftlint:disable:next function_body_length
    private func buildWrapperSource(clangCommand: String, markerFilename: String, commitSha: String) -> String {
        return """
        /**
         Clang compiler wrapper manages compilation. When a marker file, placed in the `-MF/../../../\(markerFilename)`:
         1) is missing - fallback to \(clangCommand)
         2) exists - creates empty .o file and creates .d with the same content as a marker
            (which is expected to be in the .d format)
         3) otherwise, return 1 and prints a message to the error stream.
         */

        #include <fcntl.h>     /* For system call open */
        #include <libgen.h>
        #include <string.h>
        #include <stdlib.h>
        #include <stdio.h>
        #include <stdbool.h>
        #include <sys/stat.h>
        #include <unistd.h>

         /// checks if string str has suffix prefix
         int isSuffixed(const char *str, const char *suffix)
         {
             int suffix_len = strlen(suffix);
             return (strlen(str) > suffix_len && !strcmp(str + strlen(str) - suffix_len, suffix));
         }

         void createFile(const char *path, const char *content)
         {
           FILE *fp;
           fp = fopen(path, "wb");
           if (content) {
              fwrite(content, 1, strlen(content), fp);
           }
           fclose(fp);
         }

         void createEmptyFile(const char *path)
         {
           createFile(path, NULL);
         }

         /// Writes empty .dia with no diagonostics messages (no errors, no warnings)
         /// Clang implementation: https://clang.llvm.org/doxygen/SerializedDiagnosticPrinter_8cpp_source.html
         void createPlaceholderDiaFile(const char *path)
         {
           // empty .dia file dumped using `xxd --include empty_sample.dia`
           unsigned char empty_dia[] = {
            0x44, 0x49, 0x41, 0x47, 0x01, 0x08, 0x00, 0x00, 0x30, 0x00, 0x00, 0x00,
            0x07, 0x01, 0xb2, 0x40, 0xb4, 0x42, 0x39, 0xd0, 0x43, 0x38, 0x3c, 0x20,
            0x81, 0x2d, 0x94, 0x83, 0x3c, 0xcc, 0x43, 0x3a, 0xbc, 0x83, 0x3b, 0x1c,
            0x04, 0x88, 0x62, 0x80, 0x40, 0x71, 0x10, 0x24, 0x0b, 0x04, 0x29, 0xa4,
            0x43, 0x38, 0x9c, 0xc3, 0x43, 0x22, 0x90, 0x42, 0x3a, 0x84, 0xc3, 0x39,
            0xa4, 0x82, 0x3b, 0x98, 0xc3, 0x3b, 0x3c, 0x24, 0xc3, 0x2c, 0xc8, 0xc3,
            0x38, 0xc8, 0x42, 0x38, 0xb8, 0xc3, 0x39, 0x94, 0xc3, 0x03, 0x52, 0x8c,
            0x42, 0x38, 0xd0, 0x83, 0x2b, 0x84, 0x43, 0x3b, 0x94, 0xc3, 0x43, 0x42,
            0x90, 0x42, 0x3a, 0x84, 0xc3, 0x39, 0x98, 0x02, 0x3b, 0x84, 0xc3, 0x39,
            0x3c, 0x24, 0x86, 0x29, 0xa4, 0x03, 0x3b, 0x94, 0x83, 0x2b, 0x84, 0x43,
            0x3b, 0x94, 0xc3, 0x83, 0x71, 0x98, 0x42, 0x3a, 0xe0, 0x43, 0x2a, 0xd0,
            0xc3, 0x41, 0x90, 0xa8, 0x0a, 0xc8, 0x10, 0x25, 0x50, 0x08, 0x14, 0x02,
            0x85, 0x28, 0x51, 0x04, 0x83, 0x4a, 0x16, 0x08, 0x0c, 0x82, 0xd4, 0x74,
            0x40, 0x94, 0x40, 0x21, 0x50, 0x08, 0x14, 0xa2, 0x04, 0x0a, 0x81, 0x42,
            0xa0, 0x90, 0x24, 0x10, 0x25, 0x30, 0xa8, 0xa6, 0x81, 0x28, 0x81, 0x42,
            0xa0, 0x10, 0x18, 0xd4, 0xf5, 0x40, 0x94, 0x40, 0x21, 0x50, 0x08, 0x14,
            0xa2, 0x04, 0x0a, 0x81, 0x42, 0xa0, 0x10, 0x18, 0x14, 0x00, 0x00, 0x00,
            0x21, 0x0c, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00
           };
           unsigned int empty_dia_len = 220;
           FILE *fp;
           fp = fopen(path, "wb");
           fwrite(empty_dia, 1, empty_dia_len, fp);
           fclose(fp);
         }

         bool fileExists(const char *path)
         {
           struct stat buffer;
           return (stat(path, &buffer) == 0);
         }

         /// Copies content from sourcePath to the destination (creates one if doesn't exists)
         /// Returns true for a success, false otherwise
         bool copyFile(const char *sourcePath, const char *destinationPath)
         {
           int buf_size = 512;
           char buffer[buf_size];
           size_t size;
           FILE *source = fopen(sourcePath, "r");
           FILE *destination = fopen(destinationPath, "wb");

           if (source == NULL || destination == NULL) {
               return false;
           }

           while ((size = fread(buffer, 1, buf_size, source)) > 0) {
               fwrite(buffer, 1, size, destination);
           }

           fclose(source);
           fclose(destination);

           return true;
         }

        bool isPresentInFile(const char *filePath, const char *search_line)
        {
          FILE * fp;
          char * line = NULL;
          size_t len = 0;
          ssize_t read;
          bool found = false;
          size_t search_len = strlen(search_line);

          fp = fopen(filePath, "r");
          if (fp == NULL) {
              return false;
          }

          while ((read = getline(&line, &len, fp)) != -1) {
              // Check if a line starts with search_line followed by "" (last entry) or " \\\\n" (otherwise)
              if (strncasecmp(line, search_line, search_len) == 0 &&
                  (strcmp(line + search_len, "") == 0 || strcmp(line + search_len, " \\\\\\n") == 0)
                 ) {
                  found = true;
                  break;
              }
          }

          free(line);
          fclose(fp);
          return found;
        }

        /// Decides if the file is a valid compilation unit, required to be considered in the allowed input files
        /// If not, compilation step can be safelly skip for the consumer mode
        bool isIrrelevantFile(const char *filePath)
        {
          // Skip Apple Generic Versioning file "{TargetName}_vers.c", generated during the compilation step
          return isSuffixed(filePath, "\(Self.AppleGenericVersioningSuffix)");
        }

        /// Builds a concatenation strings. First string s1 may contain NULL characters
        /// Returns the size of the output 'string'
        size_t concat(char *s1, size_t s1_len, const char *s2, char **output)
        {
            size_t concat_len = strlen(s2);
            const size_t size = s1_len + concat_len + 1;
            char *new = realloc(s1, size);
            memcpy(new + s1_len, s2, concat_len + 1);
            *output = new;
            return size - 1;
        }

        /// Adds NULL byte to the string s1
        /// Returns the size of the output 'string'
        size_t addZero(char *s1, size_t len, char **output)
        {
            char *delimiter = "\\0";
            const size_t size = len + 1 + 1;
            char *new = realloc(s1, size);
            memcpy(new + len, delimiter, 1 + 1);
            *output = new;
            return size - 1;
        }

        bool appendCallToFile(const char *filePath, const char * args[], int len)
        {
            int fd = open(filePath, O_WRONLY|O_APPEND);

            if (fd == -1) {
               return false;
            }

            // prepare a string command to store
            size_t command_len = 0;
            char *command = NULL;

            // print all arguments followed by {0x0}
            for (int i = 0 ; i < len; i++) {
                command_len = concat(command, command_len, args[i], &command);
                command_len = addZero(command, command_len, &command);
            }

            // Finish with NULL to mirror execv format that expects NULL element at the end
            command_len = addZero(command, command_len, &command);
            // finish a command with a new line character
            command_len = concat(command, command_len, "\\n", &command);

            // acquire a lock
            if (flock(fd, LOCK_EX) == -1) {
                close(fd);
                free(command);
                return false;
            }

            struct stat st0;
            fstat(fd, &st0);
            if (st0.st_nlink == 0) {
                // the file has been deleted, local compilation should happen
                flock(fd, LOCK_UN);
                close(fd);
                free(command);
                return false;
            }
            write(fd, command, command_len);
            free(command);

            if (flock(fd, LOCK_UN) == -1) {
                close(fd);
                return false;
            }
            close(fd);
            return true;
        }

        /// Builds an array of strings from contiguous set of strings, terminated with NULL element
        /// e.g. 'a{0x0}b{0x0}{0x0}' -> ['a', 'b', NULL]
        char **buildArrayFromContiguousString(char *str) {
            char **pointer = NULL;
            char *pos = str;
            int count = 0;
            while (true) {
                size_t len = strlen(pos);
                count += 1;
                pointer = realloc(pointer, count * sizeof(char*));
                pointer[count - 1] = pos;
                pos += (len + 1);
                if (len == 0 ) {
                    return pointer;
                }
            }
        }

        // Calls all commands stored in filePath location
        void fallbackPreviousCalls(const char *filePath)
        {
            int fd = open(filePath, O_RDONLY);

            if (fd == -1) {
                return;
            }

            // acquire a lock
            if (flock(fd, LOCK_EX) == -1) {
                close(fd);
                return;
            }

            // make sure the file still exists, it might be deleted while we were waiting for a lock
            if (access(filePath, F_OK) == -1) {
                close(fd);
                return;
            }

            struct stat st0;
            fstat(fd, &st0);
            if(st0.st_nlink == 0) {
                // the file has been deleted - no need to fallback anything else
                flock(fd, LOCK_UN);
                close(fd);
                return;
            }

            char * line = NULL;
            size_t len = 0;

            // iterate all lines in a file and execute commands one-by-one
            FILE * file = fdopen(fd, "r");
            ssize_t read;
            while ((read = getline(&line, &len, file)) != -1) {
              // Call all clang invocations one-by-one
              pid_t pid = fork();
              if (pid == 0) {
                // child process
                char **array = buildArrayFromContiguousString(line);
                // forked process
                execvp(line, array);
              } else {
                  // hosting process
                  int stat;
                  wait(&stat);
                  if (!WIFEXITED(stat)) {
                     //the command finish incorrectly
                     exit(1);
                  }
                  if (WEXITSTATUS(stat)) {
                     // error in the "clang" call, quit with a status code
                     exit(WEXITSTATUS(stat));
                  }
               }
            }

            free(line);
            remove(filePath);
            flock(fd, LOCK_UN);
            fclose(file);
            close(fd);
        }

        int main(int argc, const char * argv[])
        {
            const char *dependency_arg_name = "-MF";
            const char *output_arg_name = "-o";
            const char *serialize_diagnostics_arg_name = "--serialize-diagnostics";
            const char *clang_cmd = "\(clangCommand)";
            const char *markerFile = "\(markerFilename)";
            const char *compilationHistoryFile = "\(compilationHistoryFilename)";
            const char *prebuildDFile = "\(prebuildDFilename)";


            // null termination args
            const char *clang_args[argc + 1];
            clang_args[0] = clang_cmd;

            const char *dependency_file = NULL;
            const char *output_file= NULL;
            const char *input_file = NULL;
            const char *diagnostics_file = NULL;

            for (int i = 1; i < argc; i++) {
                if (strcmp(argv[i], dependency_arg_name) == 0 && i < (argc - 1) ) {
                    // called with "-MF path" pattern and not the last argument
                    clang_args[i] = argv[i];
                    i += 1;
                    clang_args[i] = argv[i];
                    dependency_file = argv[i];
                } else if (strcmp(argv[i], output_arg_name) == 0 && i < (argc - 1) ) {
                    // called with "-o path" pattern and not the last argument
                    clang_args[i] = argv[i];
                    i += 1;
                    clang_args[i] = argv[i];
                    output_file = argv[i];
                } if (strcmp(argv[i], serialize_diagnostics_arg_name) == 0 && i < (argc - 1) ) {
                    // called with "--serialize-diagnostics path" pattern and not the last argument
                    clang_args[i] = argv[i];
                    i += 1;
                    clang_args[i] = argv[i];
                    diagnostics_file = argv[i];
                } else if (
                    isSuffixed(argv[i],".m") ||
                    isSuffixed(argv[i],".mm") ||
                    isSuffixed(argv[i],".c") ||
                    isSuffixed(argv[i],".cc") ||
                    isSuffixed(argv[i],".cpp") ||
                    isSuffixed(argv[i],".c++") ||
                    isSuffixed(argv[i],".cxx")
                ) {
                    // a full list of extensions is taken from https://clang.llvm.org/docs/ClangFormatStyleOptions.html
                    // support for .m,.mm,.c,.cc,.cpp,.c++,.cxx input files
                    clang_args[i] = argv[i];
                    input_file = argv[i];
                } else {
                    // pass original parameter transparently
                    clang_args[i] = argv[i];
                }
            }

           // Verify all input arguments
           if (dependency_file == NULL) {
               fprintf(stderr, "error: missing %s input\\n", dependency_arg_name);
               exit(1);
           }
           if (output_file == NULL) {
               fprintf(stderr, "error: missing %s input\\n", output_arg_name);
               exit(1);
           }
           if (input_file == NULL) {
               fprintf(stderr, "error: missing input file\\n");
               exit(1);
           }


           // Find tmp_dir
           #pragma GCC diagnostic push
           #pragma GCC diagnostic ignored "-Wincompatible-pointer-types-discards-qualifiers"
           const char *tmp_dir = dirname(dirname(dirname(dependency_file)));
           #pragma GCC diagnostic pop

           // Find input in allowed files
           char marker_path[1024];
           sprintf(marker_path, "%s/%s", tmp_dir, markerFile);

           // A file that keeps all clang invocations
           char compilation_history_path[1024];
           sprintf(compilation_history_path, "%s/%s", tmp_dir, compilationHistoryFile);

           // Path of the prebuild.d dependency file
           char prebuild_d_path[1024];
           sprintf(prebuild_d_path, "%s/%s", tmp_dir, prebuildDFile);

           if (fileExists(marker_path))
           {
                if (
                    isIrrelevantFile(input_file) ||
                    isPresentInFile(marker_path, input_file) ||
                    isSuffixed(input_file, "\(cachedTargetMockFilename).m")
                ) {
                   // Save .d files (copy a marker file)
                   bool copyResult = copyFile(marker_path, dependency_file);
                   if (!copyResult) {
                       fprintf(stderr, "error: .d file generation failed.\\n");
                       exit(1);
                   }

                   // Create empty .o file
                   createEmptyFile(output_file);
                   // Create .dia file (if specified)
                   if (diagnostics_file != NULL) {
                       createPlaceholderDiaFile(diagnostics_file);
                   }
                   // add to compilation_history_path file so other clang execution can retrigger it if a new file is found
                   bool appended = appendCallToFile(compilation_history_path, clang_args, argc);
                   if (appended) {
                       exit(0);
                   }
                   // Failed to save, most likely some other clang fallbacked to the local compilation already
                   // so local compilation should happen
               } else {
                   // disable remote cache first to trigger prebuild phase in the next build
                   remove(marker_path);
                   // stop trying to reuse artifact for this specific remote commit sha
                   createFile(prebuild_d_path, "\(FileDependenciesWriter.skipForShaKey): \(commitSha)\\n");
                   // read from compilation_history_path, execute one by one all invocations
                   fallbackPreviousCalls(compilation_history_path);
               }
           }

           // null-terminating the args array
           clang_args[argc] = NULL;
           #pragma GCC diagnostic push
           #pragma GCC diagnostic ignored "-Wincompatible-pointer-types-discards-qualifiers"
           /// execvp takes $PATH to consideration
           return execvp(clang_cmd, clang_args);
           #pragma GCC diagnostic pop
        }
        """
    } // swiftlint:disable:next file_length
}
